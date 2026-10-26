## Purpose

Enable composefs + fs-verity on the deploy-side storage driver, so on-disk layer integrity is kernel-enforced on every `read()`, bridging pull-time sigstore verification with read-time integrity that pull-time signing alone cannot guarantee.

## ADDED Requirements

### Requirement: Composefs enable option

The system SHALL expose deploy-side options `oci.snapshotter.composefs.enable` (bool, default false) and `oci.snapshotter.composefs.fsVerity` (bool, default true when composefs is enabled).

#### Scenario: Enabling composefs emits the storage.conf key
- **WHEN** `oci.snapshotter.composefs.enable = true`
- **THEN** the emitted `/etc/containers/storage.conf.d/*.conf` contains `use_composefs = "true"` under `[storage.options.overlay]`.

### Requirement: Kernel and filesystem feasibility assertions

The system SHALL assert at deploy-eval time that the host kernel version is >= 6.6 and that the filesystem backing `/var/lib/containers` supports fs-verity (ext4 with the `verity` feature or btrfs >= 5.15).

#### Scenario: Old kernel fails cleanly
- **WHEN** composefs is enabled and the deploy host kernel is < 6.6
- **THEN** the build fails at eval time with a message naming the kernel version and the required minimum.

#### Scenario: Unsupported filesystem fails cleanly
- **WHEN** `/var/lib/containers` is on ZFS or xfs
- **THEN** the build fails at eval time with a message pointing at supported filesystems (ext4 with verity, btrfs).

### Requirement: fs-verity enforcement

When `fsVerity = true`, the system SHALL configure the storage layer such that a post-pull modification of any layer file causes subsequent reads to fail with `EIO`.

#### Scenario: Tampering fails the next read
- **WHEN** an attacker modifies a byte in an extracted layer file after pull
- **THEN** the next container-side read of that file returns an I/O error and the container process fails cleanly.

### Requirement: Default disabled

Composefs SHALL default to disabled to preserve existing deploy behavior; enabling it is opt-in per operator.

#### Scenario: Existing deploy is unaffected
- **WHEN** the option is absent from operator config
- **THEN** the storage.conf drop-in does not contain `use_composefs` and the deploy behaves identically to the pre-change baseline.

### Requirement: Coexistence with other snapshotter options

The composefs option tree SHALL coexist with the existing SOCI, stargz, and zstd:chunked option trees, and enabling composefs SHALL not conflict with any of them.

#### Scenario: SOCI + composefs both enabled
- **WHEN** the operator enables both SOCI lazy pull and composefs
- **THEN** both features apply and neither is silently disabled.
