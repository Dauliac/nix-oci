## Context

See proposal.md - Why. Grounding:

- The exploration report's original `4.2` proposal (trivy misconfig on Quadlets) collapses: trivy misconfig documentation lists only Dockerfile, Kubernetes YAML, Terraform, CloudFormation, Azure ARM, and Helm as supported target formats. Systemd `.service` / Quadlet `.container` are not parsed by trivy. This change reframes the same intent using conftest/OPA, which the project already ships.
- The `oci.policy.conftest.*` machinery (with `oci.rego` and user `extraPolicyDirs`) already validates image manifests. Extending it to validate the emitted deploy artifact is a straightforward step, not a new tool integration.
- The pipeline `category` enum in `nix/modules/oci/pipeline/_step-spec.nix:32-45` is closed and does not contain `"deploy"`. Adding a category is a single-line edit but touches a public typed surface (same as `oci-attach-referrer-substrate`).

## Goals / Non-Goals

**Goals:**
- Catch hand-overrides that defeat image-time hardening in the deploy artifact before the image is pushed.
- Reuse conftest machinery; no new tool dependency.
- Introduce a `"deploy"` pipeline category that generalises to future deploy-artifact checks (Quadlet linting, unit-file misconfig, ...).

**Non-Goals:**
- Rego policy authoring UI. Users compose extra policy dirs the same way they compose Conftest policies against the image manifest today.
- Systemd `systemd-analyze security` integration (a separate, complementary check surface, not in scope).
- Enforcing the baseline as a hard gate by default. Ship opt-in; flip default once the policy bundle proves stable.

## Decisions

### Reuse conftest, not trivy misconfig

Trivy misconfig cannot parse the target format; conftest can (Rego evaluates arbitrary JSON, and the Quadlet parser converts ini-style Quadlets to JSON for Rego evaluation). Alternative: adopt trivy misconfig on top of a Quadlet-to-Kubernetes-YAML converter. Rejected because it invents a translation layer whose semantics do not map cleanly (Kubernetes has no equivalent for `PrivateTmp`, `ProtectSystem`, `CapabilityBoundingSet`).

### New pipeline `category` value: `"deploy"`

Extending the closed enum is the smallest possible edit. `"deploy"` covers this step and any future check against the emitted deploy artifact (systemd unit, docker-compose, K8s manifest). Alternative: add each new category as a one-off. Rejected because the pattern generalises; ship the general handle now.

### Baseline Rego policy shape

`quadlet.rego` covers the seven baseline hygiene rules named in proposal.md. Rules are `deny` statements with a `msg` field explaining the violation. Alternative: `warn` statements. Rejected because deploy-artifact hygiene is either enforced or not; a warn-only mode is a slippery slope.

### Extra policy dirs composed with the baseline

`oci.container.policy.quadlet.extraPolicyDirs` is a list of paths merged into the conftest invocation via `--policy <dir>` (mirrors the image-manifest conftest invocation). Alternative: single monolithic policy dir. Rejected because composition is the pattern already used for `oci.rego` + user policies.

### Consume the emitted Quadlet as a Nix derivation

The deploy modules already produce the Quadlet as a derivation output (or as a rendered string reachable via the module's config). The pipeline step reads the derivation output at evaluation time and passes it to conftest. Alternative: emit the Quadlet to a temp file at deploy time. Rejected because pure evaluation is preferred and the derivation shape already exists.

## Risks / Trade-offs

- **False positives on unusual but valid Quadlet configurations** -> policy bundle is opt-in until proven; users can carve exceptions via extra policy dirs that override baseline rules.
- **Policy bundle churn** -> baseline evolves with systemd hardening best practices; documented and versioned.
- **Rego learning curve for users writing extra policies** -> same curve as existing conftest-on-image policies; not new.

## Migration Plan

1. Ship the baseline `quadlet.rego`, the option, and the pipeline step registration in a single change.
2. Enable in the project's own CI as a smoke test; flip default to enabled once no false positives are seen for two release cycles.
3. Documentation walks through the seven baseline rules with an example Quadlet that passes and one that fails each rule.

## Open Questions

None material.
