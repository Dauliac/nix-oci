+++
title = "Design choices and best practices"
description = "Why nix-oci defaults to non-root, distroless, FHS-structured containers with automatic naming, and how those choices keep images secure, small, and predictable"
+++

# Design choices and best practices

nix-oci ships with a set of opinionated defaults that guide users toward
production-ready containers without requiring explicit configuration. Every
default can be overridden, but the out-of-the-box experience is designed to
produce images that are **secure**, **minimal**, **reproducible**, and
**self-describing**.

This page explains *what* the defaults are and *why* they exist.

## Non-root by default

```nix
# nix/modules/oci/containers/_options/is-root.nix
isRoot = false;   # default for flake-parts (build-time)
```

Containers built with nix-oci run as a **non-root user** by default.
When `isRoot = false`, a dedicated user entry is created in `/etc/passwd`
with **UID 4000** and **GID 4000** — a deliberate choice that avoids
collisions with both system UIDs (0–999) and typical human UIDs
(1000–60000).

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

Major container security benchmarks (CIS Docker Benchmark, NIST SP
800-190, and Pod Security Standards) all recommend running as non-root.

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
  nix-oci image for a Go binary is 20–50 MB, compared to 150+ MB for
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

## FHS-structured root filesystem

Container root filesystems follow the [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.html)
layout. The `mkRoot` function uses `pkgs.buildEnv` with
`pathsToLink = ["/bin" "/lib" "/etc"]` to assemble a conventional
directory tree.

### Why it matters

- **Compatibility**: most runtime tools (shells, interpreters, linked
  libraries) expect binaries in `/bin` and libraries in `/lib`. FHS
  compliance avoids mysterious `ENOENT` errors.
- **OCI conventions**: container entrypoints are set as absolute paths
  (`/bin/myapp`), matching what operators expect from `docker inspect`.
- **Nix store paths are hidden**: the `buildEnv` symlinks Nix store
  paths into FHS locations, so the container looks like a standard Linux
  filesystem to inspection tools, log aggregators, and security
  scanners.
- **CA certificates**: every container includes `pkgs.cacert`, placing
  the Mozilla CA bundle at `/etc/ssl/certs/ca-bundle.crt`. TLS just
  works — no need to manually add certificates or set
  `SSL_CERT_FILE`.

## Automatic naming from packages

Container name and tag are **derived from the package** rather than
specified manually:

### Name resolution chain

1. `package.meta.mainProgram` (preferred — lowercase)
2. `package.pname`
3. Parsed derivation name (`builtins.parseDrvName`)
4. Base image name (when using `fromImage`)

### Tag resolution chain

1. `package.version` (preferred)
2. Base image tag (when using `fromImage`)
3. `"latest"` (fallback)

### Why it matters

- **Single source of truth**: the package already carries its name and
  version. Duplicating that information in container options is
  error-prone — especially when bumping versions.
- **Consistent naming**: `meta.mainProgram` is the canonical binary
  name in Nix. Using it as the image name means
  `docker run myapp:1.2.3` matches the binary inside the container.
- **Registry hygiene**: tags derived from package versions make it
  trivial to trace a running container back to its source.
- **Always lowercase**: the name is forced to lowercase via
  `lib.strings.toLower`, since OCI image names must be lowercase.

All automatic derivation can be overridden by setting `name` and `tag`
explicitly.

## Automatic entrypoint from packages

The entrypoint follows the same resolution chain as the name:

1. `package.meta.mainProgram` → `["/bin/myapp"]`
2. `package.pname` → `["/bin/my-script"]`
3. Parsed derivation name → `["/bin/my-script"]`

### Why it matters

- **Zero configuration for simple cases**: a `package = pkgs.caddy;`
  container automatically gets `entrypoint = ["/bin/caddy"]` — no
  manual wiring needed.
- **Convention over configuration**: the Nix ecosystem already uses
  `meta.mainProgram` to identify the primary binary. nix-oci reuses
  that convention rather than inventing its own.
- **Explicit override**: when the entrypoint needs flags or a wrapper
  script, set `entrypoint` directly — automatic derivation is skipped
  when the option is non-empty.

## Layer optimization: most stable first

When `optimizeLayers = true`, the image is split into a **stack of
layers ordered by change frequency** (most stable at the bottom):

1. **Deps layer** — runtime libraries and dependencies
2. **App layer** — the package, shadow setup, config files
3. **Debug layer** — troubleshooting tools (only in debug variant)

Each layer references its predecessors, and nix2container excludes any
store path already present in an earlier layer. This **fold-based
deduplication** guarantees zero duplicated store paths across layers.

Two strategies control sub-splitting granularity:

| Strategy | Deps sub-layers | Total layers | Best for |
|---|---|---|---|
| `"fine-grained"` (default) | Up to 80 | ~124 | Registries with many overlapping images |
| `"minimal"` | 1 | 2–3 | Few images, predictable caching |

See [Optimized layer sharing](./optimize-layers.md) for the full
explanation.

### Why it matters

- **Fast pulls**: when deploying an update that only changes application
  code, the deps layer (often the largest) is already cached on the
  node.
- **Registry efficiency**: images sharing the same runtime dependencies
  (e.g., multiple services using the same glibc + openssl) share those
  layers byte-for-byte.
- **Debug without cost**: the debug variant reuses the production deps
  and app layers. Only the thin debug layer is additional.

## Automatic healthcheck provisioning

When using `nixosConfig` with a `mainService`, nix-oci **automatically
derives** a healthcheck from the NixOS module configuration — no manual
setup required.

```nix
# The user writes this:
oci.containers.db = {
  nixosConfig.enable = true;
  nixosConfig.mainService = "postgresql";
  nixosConfig.modules = [{ services.postgresql.enable = true; }];
};

# And automatically gets:
# → OCI Healthcheck: pg_isready -h localhost -p 5432
# → Deploy: --sdnotify=healthy (Podman waits for health before READY=1)
```

### How it works

Service adapters in `_nixos/oci/service-adapters/` introspect the
actual NixOS module configuration to build a healthcheck tailored to
the service:

| Service | What the adapter inspects | Derived command |
|---|---|---|
| **nginx** | `virtualHosts.*.listen` (port, SSL), `locations` (scans for `/health`, `/healthz`, `stub_status`) | `curl -f http[s]://localhost:${port}${bestPath}` |
| **PostgreSQL** | `settings.port`, `package` | `pg_isready -h localhost -p ${port}` |
| **Redis** | `servers.<name>.port`, `servers.<name>.bind` | `redis-cli -h ${bind} -p ${port} ping` |

The nginx adapter also automatically adds `curl` to
`environment.systemPackages` so the healthcheck binary is available
inside the container.

### Why it matters

- **Zero configuration**: the most common failure mode with container
  healthchecks is forgetting to set one, or setting one that doesn't
  match the actual service configuration. Auto-derivation eliminates
  both.
- **Correct by construction**: the healthcheck is derived from the same
  NixOS options that configure the service. If you change the PostgreSQL
  port to 5433, the healthcheck automatically updates.
- **Systemd-aware**: with Podman's `--sdnotify=healthy`, the healthcheck
  feeds into systemd's service dependency graph. A database container
  reports as "ready" only when it's actually accepting connections —
  dependent services don't start prematurely.
- **Overridable**: adapters use `lib.mkDefault`, so users can always
  replace the auto-derived command with their own.

### Deploy-side systemd integration

When a container has a healthcheck and the backend is Podman, the deploy
modules automatically wire:

1. **`--sdnotify=healthy`** on the `podman run` command
2. **`Type=notify`** + **`NotifyAccess=all`** on the systemd service

This means Podman sends `sd_notify(READY=1)` to systemd only after the
healthcheck passes for the first time. Any service depending on the
container (via `After` + `Requires`) waits until the container is
genuinely healthy.

Without healthcheck integration, systemd considers a container "ready"
the instant `podman run` starts — even if the application inside takes
seconds to initialize. This race condition is a common source of
intermittent failures in multi-container deployments.

## Automatic StopSignal, WorkingDir, and Volume declarations

Beyond healthchecks, nix-oci auto-derives three more OCI config fields
from NixOS module configuration.

### StopSignal — correct graceful shutdown

Different services require different signals for graceful shutdown.
Sending `SIGTERM` (the default) to nginx kills workers mid-request;
the correct signal is `SIGQUIT`. Service adapters encode this knowledge:

| Service | Signal | Effect |
|---|---|---|
| **nginx** | `SIGQUIT` | Finish serving current requests, then exit |
| **PostgreSQL** | `SIGINT` | Rollback active transactions, clean exit |
| **Redis** | `SIGTERM` | Save dataset and exit |

When no adapter is present, the signal is derived from the systemd
`KillSignal` in the NixOS service config.

### WorkingDir — context-aware working directory

The working directory is resolved from four sources in priority order:

1. Explicit `workingDir` option
2. systemd `WorkingDirectory` from the service config
3. NixOS `services.<name>.dataDir` (e.g., `/var/lib/postgresql`)
4. User home directory (`/root` or `/home/<user>`)

This ensures that PostgreSQL containers start in `/var/lib/postgresql`
and nginx containers start in the correct document root — without any
manual configuration.

### Declared volumes — data directory hints from systemd

NixOS services declare their data directories via systemd:
`StateDirectory`, `RuntimeDirectory`, `CacheDirectory`, `LogsDirectory`.
nix-oci translates these into OCI `Volumes` metadata:

```
StateDirectory = "postgresql"  →  Volumes: { "/var/lib/postgresql": {} }
RuntimeDirectory = "nginx"     →  Volumes: { "/run/nginx": {} }
```

This tells container orchestrators which paths contain persistent data
that should survive container restarts — without requiring the user to
repeat this information.

## Automatic OCI labels

Every container image built by nix-oci is automatically annotated with
standardised OCI labels derived from package metadata, build context,
and security configuration. User-provided labels always override
auto-generated ones.

### OCI standard annotations

nix-oci populates the [`org.opencontainers.image.*`](https://specs.opencontainers.org/image-spec/annotations/)
namespace from data already present in the Nix package:

| OCI annotation | Nix source |
|---|---|
| `title` | `config.name` (container attr name) |
| `version` | `config.tag` or `package.version` |
| `description` | `package.meta.description` |
| `licenses` | `package.meta.license` (SPDX expression) |
| `url` | `package.meta.homepage` |
| `authors` | `package.meta.maintainers` |
| `documentation` | `package.meta.changelog` |
| `base.name` | Always `"scratch"` (distroless) |

### Build metadata

Labels under `io.github.dauliac.nix-oci.build.*` record how the image
was constructed:

- `system` — build platform (e.g. `x86_64-linux`)
- `optimized-layers` — whether layer deduplication was enabled
- `layer-strategy` — `fine-grained` or `minimal`
- `reproducible` — always `true` (nix-oci guarantees bit-for-bit builds)

### Hardening and Kubernetes Pod Security Standard

When `hardening.enable = true`, labels under
`io.github.dauliac.nix-oci.hardening.*` describe the container's security
posture: dropped capabilities, seccomp profile, Landlock status,
read-only rootfs, etc.

nix-oci also computes a **Kubernetes Pod Security Standard level** from
the hardening configuration:

| PSS level | Required configuration |
|---|---|
| **restricted** | `!isRoot` + `noNewPrivileges` + `capabilities.drop = ["ALL"]` + `seccomp.enable` + `readOnlyRootfs` |
| **baseline** | `hardening.enable = true` (some restrictions) |
| **privileged** | No hardening |

This label (`io.github.dauliac.nix-oci.kubernetes.pod-security-standard`)
enables Kubernetes admission controllers like
[Kyverno](https://kyverno.io/policies/other/require-image-source/require-image-source/)
or OPA/Gatekeeper to enforce policies based on the image's declared
security posture.

### Why it matters

- **Compliance**: Kyverno and OPA/Gatekeeper can enforce that images
  carry `org.opencontainers.image.source` or meet a minimum PSS level.
  Auto-labeling makes nix-oci images pass these checks without manual
  annotation.
- **Single source of truth**: labels are derived from the same Nix
  expressions that define the package and container — no drift between
  the image and its metadata.
- **Fleet visibility**: tools like `skopeo inspect`, Trivy, and
  container registries display OCI annotations. Auto-labeling makes
  every image self-describing.
- **Reproducible metadata**: all auto-generated labels are deterministic
  (no timestamps, no impure inputs) — they don't break bit-for-bit
  reproducibility.
- **Opt-out**: set `autoLabels = false` to disable all auto-generation.

## Environment variable dual-write

Environment variables declared in `environment` are written to **both**
the OCI image config (`Env`) and the container runner service (Docker/Podman
`--env` flags). See [Container metadata wiring](./container-metadata-wiring.md)
for details.

### Why it matters

- **Inspectability**: `docker inspect` and `skopeo inspect` show the
  variables baked into the image, making it easy to audit what a
  container will receive.
- **Runtime override**: operators can still override variables at
  deploy time — the runner service flags take precedence over
  image-level `Env`.

## Port wiring across layers

A single `ports = ["8080:8080"]` declaration flows to four destinations:

1. **OCI ExposedPorts** — image metadata
2. **Runner service** — Docker/Podman port mapping
3. **NixOS firewall** — `allowedTCPPorts` (NixOS deploy only)
4. **Home-manager runner** — Podman port mapping

### Why it matters

- **One declaration, no drift**: declaring a port once prevents the
  common failure mode where the image exposes a port but the firewall
  blocks it (or vice versa).
- **Secure by default**: firewall rules are opened automatically only
  for declared ports — no need to remember to update
  `networking.firewall` separately.

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

## Testing as Nix derivations

Container tests are defined declaratively and executed as reproducible
Nix derivations:

| Tool | Purpose |
|---|---|
| **Container Structure Test** | File existence, command output, metadata assertions |
| **dive** | Layer efficiency analysis |
| **dgoss** | Docker + goss behavioral tests (optional hermetic mode) |

Tests run in the Nix sandbox (or optionally with podman for dgoss),
ensuring they are reproducible across machines and CI environments.

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

## Summary of defaults

| Option | Build-time default | Deploy default | Rationale |
|---|---|---|---|
| `isRoot` | `false` | `true` | Security (build) vs. pragmatism (deploy) |
| `optimizeLayers` | `false` | `true` | Speed (build) vs. efficiency (deploy) |
| `layerStrategy` | `"fine-grained"` | `"fine-grained"` | Maximum cross-image sharing |
| `user` | `"root"` | `"root"` | Overridden by `isRoot` logic |
| Non-root UID | 4000 | 4000 | Avoids system/human UID ranges |
| `tag` | `"latest"` | `"latest"` | Overridden by package version |
| `entrypoint` | `[]` | `[]` | Auto-derived from package |
| `autoStart` | N/A | `false` | Load image only; explicit opt-in to run |
| `healthcheck` | `[]` (auto-derived with `nixosConfig`) | `[]` (auto-derived) | Service adapters derive from NixOS config |
| `stopSignal` | `null` (auto-derived) | `null` (auto-derived) | Correct graceful shutdown per service |
| `workingDir` | `null` (auto-derived) | `null` (auto-derived) | systemd → dataDir → home |
| `declaredVolumes` | `[]` (auto-derived) | `[]` (auto-derived) | systemd StateDirectory/RuntimeDirectory |
| CA certificates | Always included | Always included | TLS works out of the box |

## Further reading

- [Archive-less container building](./archive-less-container-building.md) — how nix2container avoids tar archives
- [Optimized layer sharing](./optimize-layers.md) — the two-level layering heuristic
- [Container metadata wiring](./container-metadata-wiring.md) — how options flow to OCI config, services, and firewall
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) — industry container security baseline
- [NIST SP 800-190](https://csrc.nist.gov/pubs/sp/800/190/final) — application container security guide
- [Google distroless](https://github.com/GoogleContainerTools/distroless) — the distroless philosophy
- [SLSA](https://slsa.dev/) — supply chain levels for software artifacts
