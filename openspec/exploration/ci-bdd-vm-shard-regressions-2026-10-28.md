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

### Symptom

`podman-deploy-dnsmasq--deploy-dnsmasq-resolves-hosts-entry.service` and
`podman-deploy-bind--deploy-bind-resolves-version-bind.service` restart
in a loop. dnsmasq exits with
`code=exited, status=5/NOTINSTALLED`; bind with
`status=1/FAILURE`. Then systemd restart counter climbs to 214 before
`wait_for_unit` times out.

Each individual container start is reported as `Error: container is
stopped` by the podman-side oneshot runner.

### What is NOT the cause

- Not the dnsmasq passwd bug fixed by `d4f4996`. Local verification:
  the generated `/etc/passwd` for the deploy-dnsmasq container contains
  `dnsmasq:x:998:998::/var/empty:/bin/nologin`
  so `chown -R dnsmasq` and `dnsmasq --user=dnsmasq` have a valid user.
- Not the bare-package Entrypoint bug fixed by `6c8c4e8`. The dnsmasq
  container has `nixosConfig.mainService = "dnsmasq"` and its NixOS
  eval emits a proper `_output.entrypoint =
  [ "/nix/store/.../container-entrypoint" ]`.

### What is likely

- `status=5` (`EXIT_NOTINSTALLED`) is systemd's label when ExecStart
  references a missing executable. For a containerised oneshot the
  mapping is murkier: it is the exit code the inside-container process
  returned, surfaced through podman. The container-entrypoint script
  runs:
  `mkdir -p /var/lib/dnsmasq; touch; chown; dnsmasq --test; dnsmasq -k --enable-dbus --user=dnsmasq`.
  If `dnsmasq --test` or the pre-start hook exits 5, bash propagates
  that under `set -e`.
- `--enable-dbus` may be the culprit: dbus is not running inside the
  container; dnsmasq exits early. The adapter in
  `nix/modules/_nixos-oci/service-adapters/dnsmasq.nix` does not strip
  the dbus flag. Compare against the NixOS evaluation that produces
  the entrypoint script and see whether dbus is marked wanted.
- bind failing with `status=1` is a separate story and almost certainly
  the service's config pre-flight failing; check `named-checkconf`
  path and the generated zone file.

### Entry points

1. Pull the dnsmasq container's startup log from the next CI run:
   `gh run view <run-id> --log --job <bdd-vm-deploy> \
      | grep -A 50 "deploy-dnsmasq.*container-entrypoint"`
2. Reproduce locally:
   ```
   nix build .#oci.containers."deploy-dnsmasq--deploy-dnsmasq-resolves-hosts-entry".image \
       --out-link /tmp/img
   podman load < /tmp/img && podman run deploy-dnsmasq...
   ```
3. Audit the service adapter for `--enable-dbus` and the bind adapter
   for `named-checkconf`.

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
