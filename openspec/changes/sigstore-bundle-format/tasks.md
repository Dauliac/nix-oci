## 1. Option surface

- [ ] 1.1 Add per-container option file `nix/modules/oci/_oci/signing/cosign/bundle-format.nix` with enum `"bundle" | "detached"`, default `"bundle"`; verify option accessible via `nix eval`

## 2. Emitter wiring

- [ ] 2.1 Thread the option through every cosign invocation in `nix/modules/oci/security/signing/lib.nix` (both `sign` and any `attest*` calls) as `--new-bundle-format` when option is `"bundle"`; verify emitted script contains the flag under both settings
- [ ] 2.2 Update any push-app wrapper that references cosign signature files by path so the `.sigstore.json` bundle form is picked up; verify by inspecting the push script

## 3. BDD test

- [ ] 3.1 Add `nix/modules/oci/containers/_tests/signing/bundle-format.test.nix` asserting default emit is `.sigstore.json`, detached emit produces `.sig`+`.pem`, and `cosign verify --bundle` succeeds against the bundle form; verify test passes in VM harness

## 4. Documentation

- [ ] 4.1 Add "Signature format" section to `docs/content/security/image-signing.md` covering bundle vs detached, `gh attestation verify` compatibility, and the migration path; verify by rendering the docs site locally
