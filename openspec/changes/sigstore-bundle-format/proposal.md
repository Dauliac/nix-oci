## Why

`nix/modules/oci/security/signing/lib.nix` invokes `cosign sign` today with default output format, producing detached `.sig`, `.pem`, and Rekor entry lookups. Modern sigstore verifier libraries (sigstore-python, sigstore-js) and GitHub's `gh attestation verify` consume the single-file protobuf bundle format (`.sigstore.json`) by default. Consumers of nix-oci-signed images currently need a shim to bridge the two shapes. Cosign 3.0.6 (pinned in `flake.lock`) supports the bundle format directly behind a flag; the fix is a one-line flag flip plus a small option surface for the transition period.

## What Changes

- Add per-container option file `nix/modules/oci/_oci/signing/cosign/bundle-format.nix` with enum `"bundle" | "detached"`, default `"bundle"` (cosign 3.x era).
- Thread the flag into every `cosign sign`, `cosign attest`, and `cosign attest-blob` invocation in `nix/modules/oci/security/signing/lib.nix` as `--new-bundle-format` when the option is `"bundle"`.
- Register a BDD test in `nix/modules/oci/containers/_tests/signing/bundle-format.test.nix` asserting the emitted artifact is a valid `.sigstore.json` bundle (schema check via `sigstore-python` or `cosign verify-blob --bundle`).
- Doc update: `docs/content/security/image-signing.md` gains a "Signature format" section explaining bundle vs detached and pointing at `gh attestation verify` compatibility.

## Capabilities

### New Capabilities
- `supply-chain/cosign-signing`: cosign-driven image and attestation signing with selectable output format (bundle preferred; detached retained for legacy consumers).

### Modified Capabilities
None.

## Impact

- No new runtime dependency; cosign 3.0.6 already in the pinned nixpkgs.
- Verifier tooling change for downstream consumers who rely on the old detached format: they get the bundle by default; opt-out via `oci.container.signing.cosign.bundleFormat = "detached"`.
- Composes cleanly with `cosign-attest-in-toto-wrapper` (which will also emit bundles) and with `oci-attach-referrer-substrate` (the bundle is a natural referrer with `artifactType = application/vnd.dev.sigstore.bundle.v0.3+json`).
- Does not require the referrer substrate to ship first; behavioral change is limited to signature output shape.
