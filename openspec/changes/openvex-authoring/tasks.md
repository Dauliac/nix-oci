## 1. Authoring library

- [ ] 1.1 Create `nix/modules/oci/security/vex/lib.nix` exporting `mkVexDocument { author, statements }` returning valid OpenVEX 0.2.0 JSON-LD; verify with a fixture and JSON-schema validator (`ajv-cli` in a pure check)
- [ ] 1.2 Implement eval-time assertion: `status = "not_affected"` must have a `justification` from the OpenVEX enum; verify assertion fires on malformed statement
- [ ] 1.3 Default `products[]` derivation from the container's OCI purl when omitted; verify emitted document has correct purl

## 2. Option surface

- [ ] 2.1 Create option tree `nix/modules/oci/_oci/vex/{enabled,documents,attach,spec-version}.nix`; verify option surface via `nix eval`
- [ ] 2.2 Accept `documents` as list of path-or-attrset; verify mixed inputs merge cleanly

## 3. Scanner integration

- [ ] 3.1 Extend `nix/modules/oci/security/cve/trivy/lib.nix` to pass `--vex <path>` when documents present; verify trivy invocation includes the flag
- [ ] 3.2 Extend `nix/modules/oci/security/cve/grype/lib.nix` similarly with `--vex <path>`; verify grype invocation
- [ ] 3.3 Extend `nix/modules/oci/security/cve/osv/lib.nix` (from `cve-osv-scanner`) with `--vex <path>`; verify OSV invocation
- [ ] 3.4 Add BDD scenario verifying a `not_affected` VEX statement suppresses the corresponding CVE from trivy output; verify in VM harness

## 4. Attestation attach

- [ ] 4.1 Register pipeline step `provenance/vex-attach` in `nix/modules/oci/pipeline/step-registrations.nix` (phase `post-push`, category `provenance`, deps `[ "push" ]`); verify step registered
- [ ] 4.2 Wire the step to `mkAttestation` with predicate type `openvex`; verify referrer created with `artifactType = "application/vnd.openvex+json"`

## 5. Predicate-type registration

- [ ] 5.1 Contribute `oci.pipeline.attestations.predicateTypes.openvex = "https://openvex.dev/ns/v0.2.0"`; verify entry present in registry

## 6. Documentation

- [ ] 6.1 Write `docs/content/how-to/openvex.md` covering the DSL, all five OpenVEX enum values with concrete examples, scanner integration, and verifier-side story; verify by rendering the docs site locally
