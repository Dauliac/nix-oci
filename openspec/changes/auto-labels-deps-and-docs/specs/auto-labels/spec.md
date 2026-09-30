## Purpose

Autogenerate deterministic OCI image labels from container
configuration, so every nix-oci image is self-describing to
registries, security scanners, and Kubernetes admission controllers
without the user having to hand-write metadata.

## ADDED Requirements

### Requirement: OCI standard annotations
The system SHALL emit `org.opencontainers.image.*` annotations derived
from `package.meta` and container configuration whenever
`autoLabels = true`.

#### Scenario: Package with full meta
- **WHEN** a container is built with `package` set to a derivation
  whose `meta` contains `description`, `license.spdxId`, `homepage`,
  `maintainers` and `changelog`
- **THEN** the image config Labels include
  `org.opencontainers.image.title`, `.version`, `.description`,
  `.licenses`, `.url`, `.authors`, `.documentation` and
  `.base.name = "scratch"`

#### Scenario: autoLabels disabled
- **WHEN** `autoLabels = false` on a container
- **THEN** `mkAutoLabels` returns an empty attrset and no
  `org.opencontainers.image.*` annotations are added by the
  autogeneration path

#### Scenario: Version from tag versus package
- **WHEN** `tag` is `"latest"` and `package.version` is set
- **THEN** `org.opencontainers.image.version` equals `package.version`
- **WHEN** `tag` is any other value
- **THEN** `org.opencontainers.image.version` equals `tag`

### Requirement: Build metadata labels
The system SHALL emit `io.github.dauliac.nix-oci.build.*` labels
describing how the image was constructed.

#### Scenario: Build info always present
- **WHEN** any container is built with `autoLabels = true`
- **THEN** the Labels include `build.system`, `build.optimized-layers`,
  `build.layer-strategy`, and `build.reproducible = "true"`

### Requirement: Runtime info labels
The system SHALL emit `io.github.dauliac.nix-oci.runtime.*` labels
describing runtime identity.

#### Scenario: Runtime user derivable from isRoot
- **WHEN** `isRoot = false`
- **THEN** `runtime.user = "non-root"` and `runtime.is-root = "false"`
- **WHEN** `isRoot = true`
- **THEN** `runtime.user = "root"` and `runtime.is-root = "true"`

### Requirement: Hardening labels
The system SHALL emit `io.github.dauliac.nix-oci.hardening.*` labels
when `hardening.enable = true`, and SHALL emit no `hardening.*` labels
otherwise.

#### Scenario: Hardening enabled with defaults
- **WHEN** `hardening.enable = true` with default sub-options
- **THEN** the Labels include `hardening.enabled = "true"`,
  `hardening.no-new-privileges`, `hardening.read-only-rootfs` and
  `hardening.capabilities-drop`

#### Scenario: Optional hardening features
- **WHEN** `hardening.capabilities.add` is non-empty
- **THEN** `hardening.capabilities-add` is present as a comma-joined
  list
- **WHEN** `hardening.seccomp.enable = true`
- **THEN** `hardening.seccomp-profile` is present
- **WHEN** `hardening.disableDns = true`
- **THEN** `hardening.dns-disabled = "true"` is present
- **WHEN** `hardening.noTlsTrustStore = true`
- **THEN** `hardening.tls-trust-store-removed = "true"` is present

### Requirement: Kubernetes Pod Security Standard label
The system SHALL compute one of the values `restricted`, `baseline`,
`privileged` for `io.github.dauliac.nix-oci.kubernetes.pod-security-standard`
from the hardening configuration, and SHALL emit it only when
`hardening.enable = true`.

#### Scenario: Restricted level
- **WHEN** `hardening.enable = true` and `!isRoot` and
  `noNewPrivileges` and `capabilities.drop` contains `"ALL"` and
  `seccomp.enable` and `readOnlyRootfs`
- **THEN** `kubernetes.pod-security-standard = "restricted"`

#### Scenario: Baseline level
- **WHEN** `hardening.enable = true` and any restricted-level
  precondition is not met
- **THEN** `kubernetes.pod-security-standard = "baseline"`

### Requirement: Kubernetes SecurityContext hints
The system SHALL emit `kubernetes.run-as-user`, `kubernetes.run-as-group`
and `kubernetes.fs-group` labels reflecting the effective UID/GID, and
SHALL emit `kubernetes.seccomp-profile-type = "RuntimeDefault"` when
seccomp is enabled.

#### Scenario: Non-root defaults
- **WHEN** `isRoot = false`
- **THEN** `kubernetes.run-as-user`, `kubernetes.run-as-group` and
  `kubernetes.fs-group` all equal `"4000"`

#### Scenario: Root override
- **WHEN** `isRoot = true`
- **THEN** the three Kubernetes UID/GID labels all equal `"0"`

### Requirement: Network hint labels
The system SHALL parse the `ports` list and emit
`io.github.dauliac.nix-oci.network.tcp-ports` and `.udp-ports` as
comma-joined port lists.

#### Scenario: Mixed protocols
- **WHEN** `ports = [ "8080/tcp" "53/udp" ]`
- **THEN** `network.tcp-ports = "8080"` and `network.udp-ports = "53"`

#### Scenario: Empty by omission
- **WHEN** no ports of a given protocol are present
- **THEN** the label for that protocol is omitted from the Labels attrset

### Requirement: Nix package identity labels
The system SHALL emit `io.github.dauliac.nix-oci.nix.pname`,
`.version`, `.main-program`, `.dependency-count` and `.deps` labels
derived from the container's main package and its declared
`dependencies` list.

#### Scenario: Main package identity
- **WHEN** `package` is set with `pname` and `version`
- **THEN** `nix.pname` equals `package.pname` and `nix.version`
  equals `package.version`

#### Scenario: Main program fallback
- **WHEN** `package.meta.mainProgram` is set
- **THEN** `nix.main-program` equals `meta.mainProgram`
- **WHEN** `package.meta.mainProgram` is unset but `package.pname` is
  set
- **THEN** `nix.main-program` falls back to `package.pname`

#### Scenario: Dependency count reflects list length
- **WHEN** `dependencies` has length N > 0
- **THEN** `nix.dependency-count = toString N`

#### Scenario: Dependency detail label present when list is non-empty
- **WHEN** `dependencies = [ pkgA pkgB ]` where each element is a
  derivation with `pname`, `version` and `meta.description`
- **THEN** `nix.deps` is a single label whose value is a JSON array
  string containing one object per element with keys `pname`,
  `version`, `description`, in the same order as the input list

#### Scenario: Dependency detail omitted when list is empty
- **WHEN** `dependencies = [ ]`
- **THEN** the Labels attrset contains no `nix.deps` key and no
  `nix.dependency-count` key

#### Scenario: Missing meta fields do not fail
- **WHEN** an element of `dependencies` lacks `meta.description`
- **THEN** its object in `nix.deps` still contains `pname` and
  `version`, and `description` is either absent or an empty string;
  the label is still emitted for the other elements

### Requirement: Nixpkgs security metadata labels
The system SHALL surface `package.meta.knownVulnerabilities` and
`package.meta.sourceProvenance` as labels under
`io.github.dauliac.nix-oci.security.*` and
`io.github.dauliac.nix-oci.provenance.*`.

#### Scenario: Known vulnerabilities exposed
- **WHEN** `package.meta.knownVulnerabilities` is non-empty
- **THEN** `security.known-vulnerabilities` is a comma-joined list and
  `security.insecure = "true"`

#### Scenario: Provenance exposed when present
- **WHEN** `package.meta.sourceProvenance` is a non-empty list of
  provenance descriptors with `shortName` or `name`
- **THEN** `provenance.source-type` is the comma-joined list of those
  names

### Requirement: Determinism and merge order
The system SHALL produce autogenerated labels that are a pure function
of the container configuration, and user-supplied `labels` SHALL
override any autogenerated label with the same key.

#### Scenario: No impure inputs
- **WHEN** the same container configuration is evaluated on two
  separate machines with the same nixpkgs revision
- **THEN** the autogenerated Labels attrset is byte-for-byte identical

#### Scenario: User label wins
- **WHEN** the user sets `labels."org.opencontainers.image.title" = "Custom"`
- **THEN** the final image Labels contain
  `org.opencontainers.image.title = "Custom"` even though
  `mkAutoLabels` would have produced a different value
