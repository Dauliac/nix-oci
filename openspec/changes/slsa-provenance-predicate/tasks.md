## 1. Predicate library

- [ ] 1.1 Create `nix/modules/oci/security/provenance/slsa/lib.nix` exporting `mkSlsaPredicate { flakeLockPath, flakeRef, subflakePath, builderId, buildStartedOn, buildFinishedOn }`; verify the returned JSON validates against the SLSA v1.1 provenance schema (use `ajv-cli` in a pure Nix check)
- [ ] 1.2 Implement `flake.lock` -> `resolvedDependencies[]` conversion: iterate `.nodes.<name>.locked`, emit `{ uri, digest.sha256, name }` per entry; verify with a fixture `flake.lock` that the emitted array matches expected content

## 2. Option surface

- [ ] 2.1 Create option tree `nix/modules/oci/_oci/provenance/slsa/{enabled,builder-id,predicate-type}.nix`; verify option surface via `nix eval`
- [ ] 2.2 Add eval-time assertion that enabling SLSA without a `builderId` fails cleanly; verify assertion message and exit code

## 3. Pipeline step registration

- [ ] 3.1 Register `provenance/slsa-attest` in `nix/modules/oci/pipeline/step-registrations.nix` (phase `post-push`, category `provenance`, deps `[ "push" ]`); verify step present in pipeline gate when enabled
- [ ] 3.2 Wire the step to invoke `mkAttestation` from `cosign-attest-in-toto-wrapper` with the emitted predicate; verify the referrer is created

## 4. Predicate-type registration

- [ ] 4.1 Contribute `oci.pipeline.attestations.predicateTypes.slsa = "https://slsa.dev/provenance/v1"` via a module fragment; verify entry present in the registry

## 5. BDD test

- [ ] 5.1 Add `nix/modules/oci/containers/_tests/provenance/slsa.test.nix` with scenarios: predicate validates against schema, subject digest matches pushed digest, `slsa-verifier verify-image --provenance-path <bundle> --source-uri <flake-ref>` succeeds; verify all pass in VM harness

## 6. Documentation

- [ ] 6.1 Write `docs/content/how-to/slsa-provenance.md` covering builder identity configuration, CI wiring, and consumer-side `slsa-verifier` verification; verify by rendering the docs site locally
