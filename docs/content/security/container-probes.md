+++
title = "Container probes"
description = "How nix-oci injects security tools into containers at test time without modifying the production image"
+++

# Container probes

nix-oci includes five security probes that run **inside** a container
to validate its security posture. Unlike scanners that inspect the
image archive (Trivy, Grype, Conftest), probes exercise the actual
runtime environment: capabilities, seccomp profiles, escape vectors,
and privilege escalation paths.

## The problem

Static image analysis catches known CVEs and misconfigurations, but
it cannot answer questions like:

- Does the seccomp profile actually block dangerous syscalls?
- Are there writable paths an attacker could exploit?
- Is the Docker socket accessible from inside the container?
- What capabilities does the container runtime grant?

These questions require running code **inside** the container.

## The shell-less container challenge

nix-oci builds minimal, distroless containers that often lack a
shell (`/bin/sh`). Some probes (DEEPCE, linPEAS) are shell scripts
that need an interpreter. Traditional approaches would bake test
tools into the image, but that:

- Bloats the production image with unnecessary binaries.
- Alters the security posture being tested.
- Creates a different artifact from what ships to production.

## The solution: `mkContainerProbe`

nix-oci provides a shared `mkContainerProbe` infrastructure
(in `nix/modules/oci/testing/container-probe/lib.nix`) that
**bind-mounts** tools from the Nix store into the container at test
time. The production image is never modified.

Two modes are handled transparently:

| Tool type | What gets mounted | Entrypoint |
|---|---|---|
| Static binary (amicontained, CDK) | The binary at `/probe` | `/probe` |
| Shell script (DEEPCE, linPEAS) | Static busybox at `/busybox` + script at `/probe.sh` | `/busybox sh /probe.sh` |

When `needsShell = true`, a statically-linked busybox from
`pkgs.pkgsStatic.busybox` is co-mounted to provide `/bin/sh`.
This works in any container regardless of libc or existing
tooling.

## Available probes

| Probe | Type | What it detects | Option |
|---|---|---|---|
| [amicontained](https://github.com/genuinetools/amicontained) | Static binary | Runtime, capabilities, seccomp, namespaces, AppArmor | `test.amicontained.enabled` |
| [CDK](https://github.com/cdk-team/CDK) | Static binary | Escape vectors, service accounts, sensitive files, devices | `test.cdk.enabled` |
| [DEEPCE](https://github.com/stealthcopter/deepce) | Shell script | Docker socket, privileged mode, dangerous mounts, CVEs | `test.deepce.enabled` |
| [linPEAS](https://github.com/peass-ng/PEASS-ng) | Shell script | SUID/SGID, writable paths, capabilities, kernel exploits | `test.linpeas.enabled` |

## Usage

### Enable globally

See [`oci.test.*`](../reference/flake-parts-options.html) in the flake-parts option reference.

```nix
# All containers get all probes
oci.test.amicontained.enabled = true;
oci.test.cdk.enabled = true;
oci.test.deepce.enabled = true;
oci.test.linpeas.enabled = true;
```

### Enable per container

```nix
oci.containers.my-app = {
  package = pkgs.my-app;
  test.amicontained.enabled = true;
  test.cdk.enabled = true;
};
```

### Run as flake apps

```bash
nix run .#oci-amicontained-my-app
nix run .#oci-cdk-my-app
nix run .#oci-deepce-my-app
nix run .#oci-linpeas-my-app
```

Each probe:

1. Loads the image into podman via `copyToDockerDaemon`.
2. Runs the container with the tool bind-mounted read-only.
3. Prints the output to stdout.
4. Writes a report to `$CIMERA_REPORT_DIR` when set (CI integration).
5. Exits non-zero if critical issues are found.

### Failure conditions

Each probe has declarative `failPatterns` and `warnPatterns`:

| Probe | Fails on | Warns on |
|---|---|---|
| amicontained | Privileged mode | Seccomp disabled |
| CDK | Docker socket, host block devices, bindmount escape | NET_RAW capability |
| DEEPCE | Docker socket, privileged mode | |
| linPEAS | Docker socket | Running as root |

### Hermetic mode

Each probe also provides a `mkCheck*` function that runs inside the
Nix build sandbox via `mkPodmanSandboxCheck`. This makes probe
results reproducible and cacheable:

```bash
nix build .#checks.x86_64-linux.oci-amicontained-my-app
```

Hermetic mode requires `extra-sandbox-paths = /sys/fs/cgroup` in
`nix.conf`.

## Adding a new probe

The `mkContainerProbe` abstraction makes it straightforward to add
new tools. A new probe requires only declarative configuration:

```nix
# In nix/modules/oci/testing/my-tool/lib.nix
ociLib.mkContainerProbe {
  name = "my-tool-''${containerId}";
  inherit oci;
  probe = "''${myToolPkg}/bin/my-tool";
  needsShell = false;        # true for shell scripts
  args = "--audit --quiet";
  failPatterns = [
    { pattern = "CRITICAL"; message = "Critical issue found"; }
  ];
  warnPatterns = [
    { pattern = "WARNING"; message = "Non-critical finding"; }
  ];
}
```

No shell scripting needed. The infrastructure handles image loading,
bind-mounting, report generation, and failure detection.

## Further reading

- [CVE scanning, SBOM & integrity](./cve-sbom-integrity.html): static image analysis tools
- [Hardening](./hardening.html): seccomp, AppArmor, capabilities
- [Security defaults](./security-defaults.html): non-root, distroless defaults
- [Options reference](../reference/flake-parts-options.html): all probe options
