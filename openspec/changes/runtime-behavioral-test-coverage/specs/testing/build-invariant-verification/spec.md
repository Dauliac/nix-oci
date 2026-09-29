## Purpose

Build-time invariants that CI currently claims but doesn't verify: bit-for-bit reproducibility, the P2 through G3 coherence assertions in `_nixos-oci/hardening/coherence.nix`, and inspect-level image coherence for the six label namespaces (`network.*`, `kubernetes.*`, `runtime.*`, `nix.*`, `performance.*`, `security.*`) plus the missing `org.opencontainers.image.*` fields.

## ADDED Requirements

### Requirement: Reproducible image build

The test suite SHALL verify that two independent builds of the same container produce identical OCI manifest digests.

#### Scenario: Two builds -> same digest
- **WHEN** the same container definition is built twice in separate Nix invocations (with the store cleaned or with a `--rebuild`-equivalent flag)
- **THEN** the sha256 digest of the resulting OCI image manifest is identical between the two builds

#### Scenario: Reproducible label matches reality
- **WHEN** the container is built
- **THEN** the `io.github.dauliac.nix-oci.build.reproducible = "true"` label appears only if the reproducibility scenario above holds

### Requirement: Coherence assertions fire when contradicted

The test suite SHALL verify that each documented coherence assertion in `_nixos-oci/hardening/coherence.nix` (P2, P3, P5, P6, C1, C2, C3, S1, S2, S4) fails Nix evaluation when its contradiction is present, and passes otherwise.

#### Scenario: P2 fires on NET_RAW under seccomp arg filters
- **WHEN** a container is evaluated with a configuration that triggers assertion P2 (NET_RAW phantom under seccomp arg filters)
- **THEN** Nix evaluation fails with an error message referencing P2

#### Scenario: S1 fires on strict + web-server
- **WHEN** a container is evaluated with `hardening.seccomp.profile = "strict"` and `mainService = "nginx"`
- **THEN** Nix evaluation fails with an error message referencing S1

#### Scenario: S4 fires on strict + noNewPrivileges disabled
- **WHEN** a container is evaluated with `hardening.seccomp.profile = "strict"` and `hardening.noNewPrivileges = false`
- **THEN** Nix evaluation fails with an error message referencing S4

#### Scenario: C1 fires on privileged port without NET_BIND_SERVICE
- **WHEN** a container is evaluated with `ports = ["80:80"]`, `isRoot = false`, and `hardening.capabilities.add` lacking `NET_BIND_SERVICE`
- **THEN** Nix evaluation fails with an error message referencing C1

#### Scenario: No false positives on satisfying config
- **WHEN** a container is evaluated with a configuration that does NOT trigger any of P2..S4
- **THEN** Nix evaluation succeeds

### Requirement: Coherence warnings emit when weak configuration is present

The test suite SHALL verify that documented warnings D2, D3, D4, D5, D6, G3 emit `builtins.trace`-style warnings without failing the build.

#### Scenario: D4 warns on hardening.enable=true + readOnlyRootfs=false
- **WHEN** a container is evaluated with `hardening.enable = true` and `hardening.readOnlyRootfs = false`
- **THEN** Nix evaluation succeeds and the build log contains a warning line referencing D4

#### Scenario: G3 warns when all backends are weak
- **WHEN** a container is evaluated with hardening enabled but seccomp, apparmor, capabilities, and readOnlyRootfs all off
- **THEN** Nix evaluation succeeds with a G3 warning in the build log

### Requirement: Network label coherence

The test suite SHALL verify that `network.tcp-ports` and `network.udp-ports` labels match the declared `ports`.

#### Scenario: TCP port ends up in the label
- **WHEN** a container is built with `ports = ["8080:80/tcp"]`
- **THEN** the inspected image config contains `io.github.dauliac.nix-oci.network.tcp-ports = "80"`

#### Scenario: UDP port ends up in the label
- **WHEN** a container is built with `ports = ["53:53/udp"]`
- **THEN** the label `io.github.dauliac.nix-oci.network.udp-ports = "53"` is present

### Requirement: Kubernetes label coherence

The test suite SHALL verify that Kubernetes labels reflect the container's actual security posture.

#### Scenario: PSS is `restricted` when all restricted-tier conditions hold
- **WHEN** a container is built with `hardening.enable = true`, `isRoot = false`, `hardening.noNewPrivileges = true`, `hardening.capabilities.drop = ["ALL"]`, `hardening.seccomp.enable = true`, `hardening.readOnlyRootfs = true`
- **THEN** the label `io.github.dauliac.nix-oci.kubernetes.pod-security-standard = "restricted"` is present

#### Scenario: run-as-user matches isRoot
- **WHEN** a container is built with `isRoot = false`
- **THEN** the label `io.github.dauliac.nix-oci.kubernetes.run-as-user = "4000"` is present

#### Scenario: seccomp-profile-type only when hardening + seccomp enabled
- **WHEN** a container is built with hardening + seccomp both enabled
- **THEN** the label `io.github.dauliac.nix-oci.kubernetes.seccomp-profile-type = "RuntimeDefault"` is present; when either is disabled the label is absent

### Requirement: Runtime info label coherence

The test suite SHALL verify that `runtime.user` and `runtime.is-root` labels match `isRoot`.

#### Scenario: Non-root labels
- **WHEN** a container is built with `isRoot = false`
- **THEN** labels `runtime.user = "non-root"` and `runtime.is-root = "false"` are present

#### Scenario: Root labels
- **WHEN** a container is built with `isRoot = true`
- **THEN** labels `runtime.user = "root"` and `runtime.is-root = "true"` are present

### Requirement: Nix identity label coherence

The test suite SHALL verify that `nix.*` labels reflect the container's package metadata.

#### Scenario: pname / version / main-program from package
- **WHEN** a container is built with `package = pkgs.hello`
- **THEN** labels `nix.pname = "hello"`, `nix.version = <hello version>`, and `nix.main-program = "hello"` are present

#### Scenario: dependency-count reflects declared deps
- **WHEN** a container is built with 3 `dependencies`
- **THEN** the label `nix.dependency-count = "3"` is present

### Requirement: Performance label coherence

The test suite SHALL verify that `performance.*` labels reflect the enabled performance features.

#### Scenario: allocator label is set when allocator selected
- **WHEN** a container is built with `performance.enable = true` and `performance.allocator = "jemalloc"`
- **THEN** the label `performance.allocator = "jemalloc"` is present

#### Scenario: turbo-soci label is set when SOCI enabled
- **WHEN** a container is built with `performance.turbo.soci = true`
- **THEN** the label `performance.turbo-soci = "true"` is present

#### Scenario: No performance labels when disabled
- **WHEN** a container is built with `performance.enable = false`
- **THEN** no label whose key starts with `performance.` is present

### Requirement: Security label coherence

The test suite SHALL verify that `security.known-vulnerabilities`, `security.insecure`, and `provenance.source-type` labels reflect package metadata.

#### Scenario: knownVulnerabilities produces label
- **WHEN** a container is built with a package whose meta.knownVulnerabilities contains at least one entry
- **THEN** the label `security.known-vulnerabilities` is present with the joined list and `security.insecure = "true"` is present

#### Scenario: No security labels when clean
- **WHEN** a container is built with a package whose meta has no knownVulnerabilities and normal sourceProvenance
- **THEN** neither `security.known-vulnerabilities` nor `security.insecure` labels are present

### Requirement: OCI standard annotation coherence

The test suite SHALL verify that `org.opencontainers.image.*` annotations reflect package metadata, for the fields currently unit-tested but not image-inspected.

#### Scenario: description from meta
- **WHEN** a container is built with a package whose `meta.description` is set
- **THEN** the image's `org.opencontainers.image.description` annotation equals that value

#### Scenario: licenses from meta.license.spdxId
- **WHEN** a container is built with a package whose `meta.license.spdxId = "MIT"`
- **THEN** the annotation `org.opencontainers.image.licenses = "MIT"` is present

#### Scenario: homepage / authors / documentation from meta
- **WHEN** a container is built with a package whose meta populates `homepage`, `maintainers[].name`, and `changelog`
- **THEN** annotations `url`, `authors`, and `documentation` are present with the corresponding joined values
