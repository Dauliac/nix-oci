+++
title = "Security defaults"
description = "Why nix-oci defaults to non-root, distroless, capability-dropped containers and how built-in security tooling keeps images safe"
+++

# Security defaults

nix-oci ships with security-first defaults that align with
[CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker),
[NIST SP 800-190](https://csrc.nist.gov/pubs/sp/800/190/final), and
Kubernetes [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/).

## Non-root by default

```nix
# nix/modules/oci/containers/_options/is-root.nix
isRoot = false;   # default for flake-parts (build-time)
```

Containers built with nix-oci run as a **non-root user** by default.
When `isRoot = false`, a dedicated user entry is created in `/etc/passwd`
with **UID 4000** and **GID 4000** — a deliberate choice that avoids
collisions with both system UIDs (0-999) and typical human UIDs
(1000-60000).

### Why it matters

Running as root inside a container is the single most common container
security anti-pattern. Even with Linux namespaces isolating the container
from the host, a root process:

- Can modify any file in the container filesystem, including binaries
  and libraries — an attacker who gains code execution can trivially
  persist.
- May exploit kernel vulnerabilities where UID 0 is checked as a
  capability gate.
- Violates the **principle of least privilege** — most applications do
  not need to bind privileged ports, load kernel modules, or change
  ownership of files.

### Shadow files are always present

Regardless of `isRoot`, every container includes minimal
`/etc/passwd`, `/etc/shadow`, `/etc/group`, and `/etc/gshadow` files.
For non-root containers, both a `root` entry and the application user
entry are created. This ensures that:

- `getpwnam()` and `getgrnam()` calls resolve correctly — many
  libraries (including glibc's NSS) fail hard without these files.
- Log output shows readable usernames instead of raw UIDs.
- Tools like `su` or `gosu` (when explicitly added) can look up
  accounts.

### Deploy modules default to root

The deploy modules (`modules.nixos.nix-oci`, `modules.homeManager.nix-oci`)
override `isRoot` to `true` via `mkDefault`. This is a pragmatic choice:
deploy-time containers typically run system services (Caddy, Redis,
dnsmasq) that may need to bind privileged ports or access host-mounted
volumes. Users are expected to explicitly set `isRoot = false` once they
have verified their service works without root.

## Distroless by construction

nix-oci does not use a base image. There is no `FROM alpine` or
`FROM debian:slim` — the container root filesystem is assembled from
**exactly the Nix store paths the application needs**, plus a minimal
scaffolding:

| Path | Contents |
|---|---|
| `/bin` | Binaries from `buildEnv` (package + dependencies) |
| `/lib` | Libraries from `buildEnv` |
| `/etc` | Shadow files, CA certificates (`cacert`) |
| `/tmp`, `/var/tmp` | Empty temp directories (FHS compliance) |

Nothing else. No package manager, no shell (unless explicitly added as a
dependency), no cron, no init system. This is the Nix equivalent of
Google's [distroless](https://github.com/GoogleContainerTools/distroless)
images — but generated automatically from the dependency closure rather
than hand-curated.

### Why it matters

- **Smaller attack surface**: fewer binaries means fewer potential
  exploits. A container without `curl`, `wget`, or a shell makes
  post-exploitation lateral movement significantly harder.
- **Smaller images**: only runtime dependencies are included. A typical
  nix-oci image for a Go binary is 20-50 MB, compared to 150+ MB for
  an Alpine-based equivalent with a package manager.
- **No CVE noise**: CVE scanners report vulnerabilities in installed
  packages. With no unused packages, scan results are relevant — every
  reported CVE actually affects your workload.
- **Reproducibility**: because the image contents are fully determined
  by the Nix closure, two builds of the same flake lock produce
  **bit-for-bit identical** images.

### Adding debug tools

For troubleshooting, nix-oci supports a `debug` variant that adds tools
like `curl`, `strace`, and a shell in an **additional layer** on top of
the production image. The production layers remain byte-identical in the
registry — only the debug layer is unique to the debug variant. See
[Optimized layer sharing](./optimize-layers.md) for details.

## Security tooling built in

nix-oci includes optional, declarative security scanning:

| Tool | Purpose | Option |
|---|---|---|
| **Trivy** | CVE scanning | `oci.cve.trivy.enabled` |
| **Grype** | CVE scanning | `oci.cve.grype.enabled` |
| **Vulnix** | Nix-native CVE scanning | `oci.cve.vulnix.enabled` |
| **Syft** | SBOM generation | `oci.sbom.syft.enabled` |
| **cosign** | Image signing (keyless by default) | `oci.signing.cosign.enabled` |
| **Trivy** | Credentials leak detection | `oci.credentialsLeak.trivy.enabled` |

All scanners run as Nix derivations or flake checks, integrating into CI
without extra tooling.

## Bit-for-bit reproducibility

Every image built by nix-oci is **bit-for-bit reproducible**. Given the
same `flake.lock`, two builds on different machines produce identical
image digests. This is a direct consequence of:

- Using Nix derivations (pure, hermetic builds) for all image contents.
- nix2container's archive-less approach — the JSON manifest is a
  deterministic function of the input store paths.
- No timestamps, random IDs, or host-dependent state in the build.

### Why it matters

- **Auditability**: you can verify that a deployed image matches its
  source by rebuilding and comparing digests.
- **Cache efficiency**: identical digests mean content-addressable
  registries never store duplicate data.
- **Supply chain security**: reproducible builds are a prerequisite for
  [SLSA](https://slsa.dev/) Level 3+ compliance.

## Further reading

- [Automatic OCI labels](./automatic-labeling.md) — how labels encode security posture and K8s PSS level
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) — industry container security baseline
- [NIST SP 800-190](https://csrc.nist.gov/pubs/sp/800/190/final) — application container security guide
- [Google distroless](https://github.com/GoogleContainerTools/distroless) — the distroless philosophy
- [SLSA](https://slsa.dev/) — supply chain levels for software artifacts
