## Purpose

Evaluate conftest/OPA Rego policies against the emitted Quadlet file to catch hand-overrides that defeat image-time hardening (for example, a deploy-time `PrivateTmp=no` that undoes the image's `hardening.noNewPrivileges = true`).

## ADDED Requirements

### Requirement: Bundled baseline Rego policy

The system SHALL ship a baseline Rego policy `quadlet.rego` that flags Quadlets violating minimum hygiene: `NoNewPrivileges != yes`, `ProtectSystem` not in `{ yes, strict, full }`, `PrivateTmp = no`, `CapabilityBoundingSet` containing `CAP_SYS_ADMIN` without explicit allow, `RestrictSUIDSGID = no`, absent `User=`.

#### Scenario: Baseline policy flags PrivateTmp=no
- **WHEN** the emitted Quadlet has `PrivateTmp=no` in its `[Service]` block
- **THEN** conftest reports a policy violation naming the offending key and the pipeline gate fails.

### Requirement: User policy composition

The system SHALL accept a per-container list of extra policy directories `oci.container.policy.quadlet.extraPolicyDirs`, merged with the bundled baseline for the conftest invocation.

#### Scenario: Extra policy dir adds a new rule
- **WHEN** the operator ships an extra policy that rejects `AmbientCapabilities=CAP_NET_ADMIN`
- **THEN** conftest evaluates both the baseline and the extra rule against the Quadlet.

### Requirement: Pipeline step under the deploy category

The system SHALL register the check as `deploy/quadlet-conftest` (phase `build-check`, category `deploy`, backend `pure`) so it runs before the image is pushed.

#### Scenario: Step appears in the gate when enabled
- **WHEN** `oci.container.policy.quadlet.enabled = true`
- **THEN** the pipeline gate includes `deploy/quadlet-conftest` and it runs before `push`.

### Requirement: Extend the pipeline category enum

The system SHALL extend the pipeline step-spec `category` enum to include `"deploy"` so that this and future deploy-artifact checks validate.

#### Scenario: Deploy category validates
- **WHEN** a pipeline step is registered with `category = "deploy"`
- **THEN** `openspec validate` and the pipeline gate accept the registration without a schema error.

### Requirement: Opt-in default

The check SHALL default to disabled (`oci.container.policy.quadlet.enabled = false`) so early adopters can trial the policy bundle before it becomes mandatory.

#### Scenario: Default is disabled
- **WHEN** a fresh project enables the pipeline with no policy-specific config
- **THEN** the `deploy/quadlet-conftest` step is not present in the gate.
