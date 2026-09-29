## Purpose

Verifies that hardening, performance, GPU, and container-probe features have the behavior they advertise inside a real running container, not merely the label or manifest field that says so. The gap this closes: today CI checks that seccomp = "strict" sets a label; this capability checks that a blocked syscall actually fails at runtime.

## ADDED Requirements

### Requirement: Hardening features SHALL be verified at runtime, not only via labels

Each hardening feature (`oci.containers.<n>.hardening.*`) that produces a runtime effect (seccomp, apparmor, capabilities, rootfs, noNewPrivileges, disableDns, noTlsTrustStore) SHALL have at least one BDD scenario at `level = "runtime"` or `level = "deploy"` that exercises the feature's effect from inside a running container and asserts the expected behavior. A scenario named `runtime-*` MUST run at `level = "runtime"` (currently several are misnamed and run at build level).

#### Scenario: Seccomp blocks disallowed syscall
- **WHEN** a container is built with `hardening.seccomp = "strict"` and run under podman with the seccomp profile applied
- **THEN** invoking a syscall blocked by the strict profile (for example `mount` from a probe binary) SHALL exit nonzero with EPERM and the test SHALL assert that failure

#### Scenario: readOnlyRootfs prevents writes
- **WHEN** a container is built with `hardening.rootfs.readOnly = true` and run under podman with `--read-only`
- **THEN** writing to any path outside declared volumes SHALL fail with EROFS and the test SHALL assert that failure

#### Scenario: capabilities drop actually removes capabilities
- **WHEN** a container is built with `hardening.capabilities.drop = ["ALL"]` and run under podman with `--cap-drop=ALL`
- **THEN** reading `/proc/1/status` from inside the container SHALL show `CapEff: 0000000000000000`

#### Scenario: noNewPrivileges blocks setuid escalation
- **WHEN** a container is built with `hardening.privileges.noNewPrivileges = true` and includes a setuid binary
- **THEN** executing the setuid binary SHALL fail to gain privileges (the effective UID stays the calling UID)

#### Scenario: disableDns breaks name resolution
- **WHEN** a container is built with `hardening.dns.disable = true`
- **THEN** `getaddrinfo("example.com")` from inside the container SHALL fail
- **AND** `/etc/nsswitch.conf` SHALL contain `hosts: files`

#### Scenario: noTlsTrustStore breaks HTTPS
- **WHEN** a container is built with `hardening.tls.removeStore = true` and includes curl
- **THEN** `curl https://example.com` SHALL fail with a certificate verification error

#### Scenario: apparmor profile enforces at runtime
- **WHEN** a container is built with `hardening.apparmor.profile = "moderate"` and the host has AppArmor loaded
- **THEN** an operation denied by the moderate profile (for example writing to `/proc/sys/*`) SHALL fail with EACCES
- **AND** the test SHALL skip cleanly on hosts without AppArmor support

### Requirement: Performance features SHALL be verified in the built image or at runtime

Each performance feature (`oci.containers.<n>.performance.*`) SHALL have at least one BDD scenario that observes its effect in the built OCI manifest (compression algorithm, layer count, env vars) or at runtime (LD_PRELOAD injection, env var visibility from `/proc/1/environ`, SOCI ztoc presence).

#### Scenario: Allocator injects LD_PRELOAD
- **WHEN** a container is built with `performance.allocator = "jemalloc"` and run under podman
- **THEN** `/proc/1/environ` inside the container SHALL contain `LD_PRELOAD=<store-path>/lib/libjemalloc.so`

#### Scenario: Allocator-specific tunable env vars appear
- **WHEN** a container is built with `performance.allocator = "jemalloc"` and `performance.allocatorConfig = { narenas = "4"; }`
- **THEN** `/proc/1/environ` SHALL contain `MALLOC_CONF=narenas:4`

#### Scenario: glibc tunables preset expands into env
- **WHEN** a container is built with `performance.glibcTunablesPreset = "high-throughput"`
- **THEN** the built image's OCI Env SHALL contain a `GLIBC_TUNABLES=` entry matching the preset expansion

#### Scenario: Compression algorithm applied to layers
- **WHEN** a container is built with `performance.compression = "zstd"`
- **THEN** every layer descriptor in the built manifest SHALL have mediaType `application/vnd.oci.image.layer.v1.tar+zstd`

#### Scenario: SOCI zTOC is generated
- **WHEN** a container is built with `performance.turbo.soci = true` and pushed to the VM's local registry
- **THEN** the registry SHALL contain a SOCI ztoc referrer manifest for the image
- **AND** the ztoc SHALL be a valid zTOC (parseable by `soci` CLI)

#### Scenario: SOCI span size is applied
- **WHEN** a container is built with `performance.turbo.soci = true` and `performance.turbo.sociSpanSize = "1MiB"`
- **THEN** the generated zTOC SHALL reflect the 1 MiB span size

#### Scenario: hwcaps library variants are present in image
- **WHEN** a container is built with `performance.hwcaps.enable = true`, `performance.hwcaps.levels = ["x86-64-v3"]`, and `performance.hwcaps.libraries = [ pkgs.someLib ]`
- **THEN** the built image SHALL contain the library under a hwcaps path such as `/lib/glibc-hwcaps/x86-64-v3/`

#### Scenario: startup.ldSoCache generates /etc/ld.so.cache
- **WHEN** a container is built with `performance.startup.ldSoCache = true`
- **THEN** the built image SHALL contain a valid `/etc/ld.so.cache` file

### Requirement: GPU features SHALL be verified in the built image

Each GPU option (`oci.containers.<n>.gpu.*`) SHALL have at least one inspect-level scenario that verifies the labels, env vars, or library files are present in the built image. Runtime GPU verification is out of scope because CI has no GPU hardware.

#### Scenario: gpu.enable produces expected labels and env
- **WHEN** a container is built with `gpu.enable = true`, `gpu.capabilities = "compute,utility"`, and `gpu.cudaVersion = "12.1"`
- **THEN** the built image's Config.Labels SHALL contain `io.github.dauliac.nix-oci.gpu.enabled = "true"`, `.gpu.capabilities = "compute,utility"`, and `.gpu.cuda-version = "12.1"`
- **AND** Config.Env SHALL contain `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=compute,utility`

#### Scenario: gpu.runtimeLibraries places libraries in image
- **WHEN** a container is built with `gpu.enable = true` and `gpu.runtimeLibraries = ["cudart"]`
- **THEN** the built image SHALL contain `libcudart.so*` under a Nix store path referenced by an LD path

#### Scenario: gpu.forwardCompat includes compat libraries
- **WHEN** a container is built with `gpu.enable = true` and `gpu.forwardCompat = true`
- **THEN** the built image SHALL contain the CUDA forward-compat library and `LD_LIBRARY_PATH` SHALL precedence-order it before the driver-provided libs

### Requirement: Container probes SHALL prove end-to-end delivery

Each container probe (`oci.test.{amicontained,cdk,deepce,linpeas}.enabled`) SHALL have at least one BDD scenario that enables the probe, executes it against a container-under-test, and asserts the probe emits a non-empty report. The four example flakes in `examples/flake/testing/minimalist-with-{amicontained,cdk,deepce,linpeas}-01.nix` SHALL be gated in CI (currently they're explicitly excluded at `tests/flake.nix:55-61`).

#### Scenario: amicontained probe emits a report
- **WHEN** the `oci-amicontained-<container>` app is executed against a built container
- **THEN** the app SHALL exit 0 and produce a report containing at least `Container Runtime:` and `Has Namespaces:` sections

#### Scenario: CDK probe emits a report
- **WHEN** the `oci-cdk-<container>` app is executed
- **THEN** the app SHALL exit 0 and emit a summary that includes the escape-vector checklist

#### Scenario: DEEPCE probe emits a report
- **WHEN** the `oci-deepce-<container>` app is executed
- **THEN** the app SHALL exit 0 and emit a report; `NIX_OCI_REPORT_DIR` if set SHALL contain the report file

#### Scenario: linPEAS probe emits a report
- **WHEN** the `oci-linpeas-<container>` app is executed
- **THEN** the app SHALL exit 0 and emit a report with a `Basic information` header

### Requirement: Probe framework primitives SHALL be unit-tested

`mkContainerProbe` and `mkHermeticContainerProbe` SHALL have unit-level tests (nix-unit or BDD build-level) that verify: (a) `needsShell = true` co-mounts busybox and constructs the correct `--volume` flags, (b) `failPatterns` cause the probe to exit nonzero, (c) `warnPatterns` emit warnings without failing, (d) `NIX_OCI_REPORT_DIR` when set causes a report file to be written.

#### Scenario: needsShell = true co-mounts busybox
- **WHEN** `mkContainerProbe` is invoked with `needsShell = true`
- **THEN** the resulting script SHALL contain a `--volume` flag mounting `pkgs.pkgsStatic.busybox`

#### Scenario: failPattern causes nonzero exit
- **WHEN** a probe is invoked whose command output matches a `failPatterns` entry
- **THEN** the probe SHALL exit nonzero

#### Scenario: warnPattern emits warning without failing
- **WHEN** a probe is invoked whose command output matches a `warnPatterns` entry but no `failPatterns` entry
- **THEN** the probe SHALL exit 0 and emit a warning line prefixed `WARN:`

#### Scenario: NIX_OCI_REPORT_DIR writes report
- **WHEN** a probe is invoked with `NIX_OCI_REPORT_DIR=/tmp/reports` set in the environment
- **THEN** `/tmp/reports/<probe-name>.report` SHALL exist and contain the probe's stdout
