## 1. Option surface

- [ ] 1.1 Add per-container option file `nix/modules/oci/_oci/sbom/syft/spec-version.nix` with enum `"1.5" | "1.6"`, default `"1.6"`; verify option accessible via `nix eval`
- [ ] 1.2 Add scaffolded per-container option file `nix/modules/oci/_oci/sbom/syft/spdx-version.nix` with enum `"2.3" | "3.0"`, default `"2.3"`, plus assertion when `"3.0"` requested; verify assertion fires with actionable message

## 2. Emitter wiring

- [ ] 2.1 Thread the CycloneDX version through the syft invocation in `nix/modules/oci/security/sbom/lib.nix` as `-o cyclonedx-json@<version>=<path>`; verify emitted script contains the pinned version
- [ ] 2.2 Extend the emitter to honour `spdxVersion = "2.3"` (current path) and fail with the assertion for `"3.0"`; verify with `nix eval` under both settings

## 3. BDD test

- [ ] 3.1 Add `nix/modules/oci/containers/_tests/sbom/cyclonedx-version.test.nix` asserting emitted SBOM has `specVersion == "1.6"` by default; verify test passes in VM harness
- [ ] 3.2 Add scenario: image with an OpenSSL closure produces at least one `component.type == "cryptographic-asset"`; verify scenario passes

## 4. Documentation

- [ ] 4.1 Add "Schema version" callout to `docs/content/security/vulnerability-scanning.md` (SBOM section) with a note on when to pin to 1.5 and the SPDX 3.0 watching-brief; verify by rendering the docs site locally
