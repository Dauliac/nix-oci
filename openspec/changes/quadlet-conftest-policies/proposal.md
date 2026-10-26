## Why

The pipeline runs conftest against the image manifest (via `oci.policy.conftest.*`) and container-structure-test with auto-coherence assertions (via `mkCoherenceCst`). Neither checks the emitted deploy artifact: the generated Quadlet file (`.container`) or the emitted NixOS `systemd.services.<name>` unit. A user can request `hardening.noNewPrivileges = true` on the image and then hand-override `PrivateTmp = "no"` in a deploy-time `extraConfig`, silently defeating the posture. Trivy's misconfig scanner does not parse systemd/Quadlet files (Dockerfile, Kubernetes YAML, Terraform, CloudFormation, ARM, Helm only per current trivy docs), so the exploration report's original "trivy misconfig for Quadlets" proposal collapses. The right shape reuses the machinery we already have: conftest + Rego policies, targeted at the emitted Quadlet file.

## What Changes

- Add a policy bundle `nix/modules/oci/security/policy/conftest/policies/quadlet.rego` covering baseline Quadlet hygiene:
  - `NoNewPrivileges != "no"`
  - `ProtectSystem in { "yes", "strict", "full" }`
  - `PrivateTmp != "no"`
  - `CapabilityBoundingSet` does not contain `CAP_SYS_ADMIN` unless explicitly allowed
  - `RestrictSUIDSGID != "no"`
  - `[Container]` block has an explicit `User=` (not root by omission)
- Extend the closed enum in `nix/modules/oci/pipeline/_step-spec.nix` `category` with `"deploy"` (new category for steps that consume the emitted deploy artifact, not the image).
- New per-container option tree `nix/modules/oci/_oci/policy/quadlet/`:
  - `enabled.nix` (bool, default false initially, flip to true once the policy bundle stabilises)
  - `extra-policy-dirs.nix` (list of paths for user policy composition)
- Register pipeline step `deploy/quadlet-conftest` in `nix/modules/oci/pipeline/step-registrations.nix` (`phase = "build-check"`, `category = "deploy"`, backend `"pure"`). The step takes the emitted Quadlet file (accessible as a Nix derivation output from the deploy modules) and runs conftest against the bundled Rego.
- BDD test `nix/modules/oci/containers/_tests/deploy/quadlet-conftest.test.nix`: (a) a well-formed Quadlet passes, (b) a Quadlet with `PrivateTmp=no` fails with the expected policy violation, (c) a user-supplied extra policy dir composes correctly.
- Docs: extend `docs/content/security/policy-integrity-testing.md` with a "Deploy artifact policy" subsection.

## Capabilities

### New Capabilities
- `deploy/policy-quadlet`: conftest-driven Rego policy evaluation of the emitted Quadlet file, catching hand-overrides that defeat image-time hardening.

### Modified Capabilities
- `pipeline/cve-scanning` (indirectly): pipeline `category` enum grows `"deploy"`, unblocking future deploy-artifact checks.

## Impact

- Reuses conftest machinery already in the pipeline; no new tool dependency.
- Non-breaking: opt-in via option; disabled by default until policy bundle stabilises.
- Complements image-time hardening: catches the "posture defeated in deploy override" case that no other check catches.
- Corrects the exploration report's `4.2` proposal (which assumed trivy misconfig supports systemd; it does not).
