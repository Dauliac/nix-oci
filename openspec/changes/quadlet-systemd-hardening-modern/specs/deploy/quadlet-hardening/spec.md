## Purpose

Fold newer systemd (>= 250) unit hardening directives (`RestrictNetworkInterfaces=`, `ProtectHostname=`, `RestrictFileSystems=`, `ProtectProc=`) into the emitted Quadlets and NixOS units, so deploy-time defence-in-depth catches attacks that image-level hardening cannot express.

## ADDED Requirements

### Requirement: RestrictNetworkInterfaces=

The system SHALL emit `RestrictNetworkInterfaces=<list>` in the emitted unit's `[Service]` section when `hardening.systemd.restrictNetworkInterfaces` is set to a non-empty list.

#### Scenario: Whitelist a single interface
- **WHEN** the option is `[ "lo" ]`
- **THEN** the emitted unit contains `RestrictNetworkInterfaces=lo` and the container process cannot bind to other interfaces at runtime.

### Requirement: ProtectHostname=

The system SHALL emit `ProtectHostname=yes` when `hardening.systemd.protectHostname = true`.

#### Scenario: Container cannot change hostname
- **WHEN** the option is true and the container attempts `sethostname()`
- **THEN** the syscall returns EPERM.

### Requirement: RestrictFileSystems=

The system SHALL emit `RestrictFileSystems=<list>` in the emitted unit when `hardening.systemd.restrictFileSystems` is set.

#### Scenario: Whitelist filesystem family groups
- **WHEN** the option is `[ "@basic-api" ]`
- **THEN** the emitted unit contains `RestrictFileSystems=@basic-api` and mounting outside the whitelisted families fails at runtime.

### Requirement: ProtectProc=

The system SHALL emit `ProtectProc=<value>` in the emitted unit, defaulting to `"invisible"`.

#### Scenario: Default is invisible
- **WHEN** no explicit value is set
- **THEN** the emitted unit contains `ProtectProc=invisible` and `/proc` entries for other users are not visible from inside the container.

### Requirement: systemd version guard

The system SHALL assert at deploy-eval time that the host `systemd` version is >= 250 when any of the new directives is enabled, and MUST print an actionable failure message otherwise.

#### Scenario: Older systemd fails cleanly
- **WHEN** the deploy target has systemd < 250 and a new directive is enabled
- **THEN** the build fails at eval time with a message identifying the host version and the required minimum.

### Requirement: Rootless behavior documented

The system SHALL document in the how-to which directives are silently ignored by user-mode systemd, so operators of home-manager rootless quadlets are not surprised when a directive appears in the unit but does not enforce.

#### Scenario: Documentation covers each directive
- **WHEN** the how-to is reviewed
- **THEN** each of the four new directives has an explicit "rootless behavior" note.
