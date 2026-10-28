# Remaining `check-bdd-vm` shard regressions

**Status (last run `6c8c4e8`):** 4 of 7 shards green (`nixos`, `environment`,
`invariant`, `entrypoint`). 3 shards red. Each is its own debugging pass;
they are decoupled by the shift-left matrix architecture landed earlier
this session (commits `7e7c7e2`, `953e3f3`, `343ee0a`).

The shards share `_vm-defaults` sizing, the fixed shadow files from
`868ead8` and `d4f4996`, and the entrypoint fallback from `6c8c4e8`.
Everything downstream of that is service-specific.

---

## 1. `check-bdd-vm (runtime)`

### Symptom

First failing unit is now
`podman-runtime-hardening-apparmor--runtime-proc-sys-write-denied.service`
in `state=failed`, followed by several `podman-runtime-hardening-seccomp-*`
services with `exit-code`. The prior-blocking failure
(`runtime-no-apparmor-write-succeeds`) is gone, cleared by the Entrypoint
fallback.

### What is known

- Test spec: `nix/modules/oci/containers/_tests/runtime/apparmor.test.nix`
  for the apparmor cases;
  `nix/modules/oci/containers/_tests/runtime/seccomp.test.nix` for seccomp.
- All failing containers use `package = pkgs.busybox` with
  `hardening.enable = true` and a hardening flag toggled per scenario.
- The containers reach the `oci-load` step and start under podman; they
  then exit with `code=exited, status=1/FAILURE` (seccomp) or hit the
  BDD assertion harness (apparmor denied-write).
- Host AppArmor state on `ubuntu-24.04` runners is likely in play for
  the denied-write test; podman uses `--security-opt apparmor=profile`
  derived from the container config.

### Entry points for next session

1. Pull the current CI log for a specific service and read its stderr:
   `gh run view <run-id> --log --job <bdd-vm-runtime-job-id> \
      | grep -A 20 "podman-runtime-hardening-seccomp--runtime-strict-blocks-mount"`
2. Build the failing container's image locally and `podman run` it with
   the same flags podman uses (dump via
   `nix eval .#checks.x86_64-linux.bdd-vm-runtime.nodes.machine.config.virtualisation.oci-containers.containers.<name>.extraOptions`).
3. For denied-write: verify the generated AppArmor profile actually loads
   in the VM (`nix eval ...oci.container._output.seccompProfile` and the
   apparmor equivalent).

---

## 2. `check-bdd-vm (performance)`

### Symptom

`podman-performance-turbo-soci-runtime--runtime-soci-span-size-1MiB.service`
exits with `exit-code`; subsequent `wait_for_unit multi-user.target`
times out at 900s because the restart loop keeps the unit from reaching
`active`.

### What is known

- Test spec:
  `nix/modules/oci/containers/_tests/performance/turbo/soci-span-size.test.nix`
  (search the `_tests/performance/turbo/` tree).
- SOCI tests rely on the `nix2container-turbo` push backend producing a
  SOCI index and a snapshotter inside the VM pulling it. Requires:
  - `oci.turbo.enable = true` in the test VM.
  - A SOCI-aware snapshotter (`soci-snapshotter`, `nix-snapshotter`, or
    the containerd-stargz-grpc shim).
  - The container's image must have SOCI referrer metadata.
- `openspec/changes/composefs-fsverity-snapshotter/` is a related draft.
- Previously the shard was often preempted by Azure spot before hitting
  this; it only started surfacing after the matrix split shortened the
  shard.

### Entry points

1. Check whether the SOCI snapshotter is actually running inside the VM:
   `grep -i "soci\|snapshotter" <job-log>` from CI.
2. Inspect the generated image's SOCI referrer:
   `nix eval .#checks.x86_64-linux.bdd-vm-performance.nodes.machine.config.oci.containers."performance-turbo-soci-runtime--runtime-soci-span-size-1MiB"._output.sociIndex`
   (or similar).
3. The ADR search path:
   `openspec/exploration/perf-architecture.md`,
   `openspec/exploration/turbo-snapshotter.md`,
   `openspec/exploration/nix-snapshotter-research.md`.

---

## 3. `check-bdd-vm (deploy)`

### Status after ff2eb32 + 7989293

The deploy shard surfaced three independent sub-failures. Each needs
its own debugging pass; none are architectural.

### 3a. dnsmasq - EC_FILE (FIXED by d7744cc)

**Symptom**: `podman-deploy-dnsmasq--...service` exited with
`status=3/NOTIMPLEMENTED` and restarted in a loop. Dnsmasq's internal
exit code 3 is `EC_FILE` ("file access error").

**Confirmed cause** (verified locally):

    $ dnsmasq --test -C /nix/store/.../dnsmasq.conf
    dnsmasq: cannot read /etc/dnsmasq-conf.conf: No such file ...
    exit=3

nixpkgs' `services.dnsmasq` adds `conf-file = /etc/dnsmasq-conf.conf`
and `resolv-file = /etc/dnsmasq-resolv.conf` whenever
`resolveLocalQueries = true` (the default). On a NixOS host those
files are created by the service preStart `touch
/etc/dnsmasq-{conf,resolv}.conf` on a writable /etc. In a container,
/etc is nix-store-backed and the podman overlay cannot persist the
touched files reliably.

**Fix** (d7744cc): the dnsmasq service adapter now sets
`services.dnsmasq.resolveLocalQueries = lib.mkDefault false` which
removes both config lines from the generated dnsmasq.conf. Containers
never want the local-resolver wiring anyway.

**NOT the cause** (also verified fixed earlier in the session):
- The dnsmasq passwd bug (d4f4996).
- The bare-package Entrypoint bug (6c8c4e8).
- The `--enable-dbus` dbus-missing issue (ff2eb32).

### 3b. postgresql - status 125 (podman error)

**Symptom**: `podman-deploy-postgresql--...service` exits with
`status=125/n/a`. Status 125 is podman's "command invocation failure"
- the container runtime itself refused to start the container.

**Entry points**:
1. Inspect `extraOptions` and `cmd` for the postgresql container:
   `nix eval .#checks.x86_64-linux.bdd-vm-deploy.nodes.machine.config.virtualisation.oci-containers.containers."deploy-postgresql--...".extraOptions`
2. Compare to a passing container (e.g. the nginx-nixos one in the
   `nixos` shard which is green).
3. Status 125 is often a mount-path or `--user` mismatch.

### 3c. wiring-volumes - status 125 (podman error)

**Symptom**: `podman-deploy-wiring-volumes--...service` exits with
`status=125/n/a`.

Same category as 3b. The wiring tests set up specific volume
scenarios; one of them may be creating a bind mount that podman
refuses.

**Entry points**:
1. The spec at
   `nix/modules/oci/containers/_tests/deploy/wiring-volumes.test.nix`
   drives this container.
2. Inspect the generated `--volume` flags on
   `virtualisation.oci-containers.containers."deploy-wiring-volumes--...".volumes`.

### 3d. deploy-bind - BLOCKED (upstream nixpkgs bug)

**Status**: Excluded from the matrix in 7989293. Re-enable when
nixpkgs reorders the `named-checkconf` arguments or sets
`doCheck = false` on the configFile derivation.

**Reference**: `nix/modules/oci/testing/test-vm.nix` has an inline
comment at the `bddVmExcludedGroups = [ "probes-e2e" "deploy-bind" ]`
line documenting the full reproduction.

---

## Infrastructure state (shared across the three)

- Matrix architecture: `nix/docs.nix` + `.github/workflows/ci.yml` +
  `.github/workflows/bdd-vm-groups.json` +
  `.github/workflows/bdd-containers.json`.
- VM defaults (`diskSize=32768`, `cores=8`, `memorySize=4096`):
  `nix/modules/oci/testing/_vm-defaults/default.nix`.
- Shared VM wiring: `nix/modules/oci/testing/test-vm.nix`.
- Shadow files + uid allocation:
  `nix/modules/_nixos-oci/users/lib.nix`,
  `nix/modules/_nixos-oci/users/outputs.nix`.
- Deploy-side image config (where the Entrypoint fallback lives):
  `nix/modules/deploy/nix-oci/options/_containers/image.nix`.

The 42-shard `check-bdd-app` matrix is still blocked by
`needs: check-bdd-vm` from `953e3f3`. Once the three shards above are
green, that matrix will run and reveal any further per-container
regressions.
