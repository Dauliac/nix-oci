## 1. Enum extension

- [ ] 1.1 Extend the `category` enum in `nix/modules/oci/pipeline/_step-spec.nix` with `"deploy"`; verify existing steps still validate

## 2. Baseline Rego policy

- [ ] 2.1 Create `nix/modules/oci/security/policy/conftest/policies/quadlet.rego` with `deny` rules covering the seven baseline hygiene rules from the design doc; verify each rule fires on a hand-crafted offending Quadlet and passes on a clean one
- [ ] 2.2 Add fixture Quadlets under `nix/modules/oci/security/policy/conftest/fixtures/quadlet/{good,bad-privatetmp,bad-no-user,bad-caps}.container`; verify conftest classifies each fixture correctly

## 3. Option surface

- [ ] 3.1 Create per-container option tree `nix/modules/oci/_oci/policy/quadlet/{enabled,extra-policy-dirs}.nix`; verify option surface via `nix eval`

## 4. Pipeline step registration

- [ ] 4.1 Register `deploy/quadlet-conftest` in `nix/modules/oci/pipeline/step-registrations.nix` (phase `build-check`, category `deploy`, backend `pure`); verify step in gate when enabled
- [ ] 4.2 Wire the step to consume the emitted Quadlet derivation output and invoke conftest with the baseline + user extra dirs; verify by inspecting the emitted script

## 5. BDD test

- [ ] 5.1 Add `nix/modules/oci/containers/_tests/deploy/quadlet-conftest.test.nix` with scenarios: well-formed Quadlet passes, `PrivateTmp=no` Quadlet fails with expected message, user extra policy composes; verify all pass in VM harness

## 6. Documentation

- [ ] 6.1 Extend `docs/content/security/policy-integrity-testing.md` with "Deploy artifact policy" subsection walking through the seven baseline rules with a passing/failing example each; verify by rendering the docs site locally
