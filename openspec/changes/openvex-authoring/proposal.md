## Why

Trivy, grype, vulnix, and (via `cve-osv-scanner`) OSV-Scanner all emit raw CVE lists. In practice most listed CVEs are non-exploitable in the specific closure: the vulnerable path is unreachable, disabled at compile time, sandboxed, or protected by a caller-side check. Without machine-consumable non-exploitability documentation, maintainers face an endless ship-blocking treadmill of manual triage. OpenVEX (`https://github.com/openvex/spec`) is the standards-track solution: JSON-LD documents whose statements say "for this product, this CVE has status `not_affected` with justification `<enum>`". Trivy and grype consume OpenVEX natively via `--vex <path>`.

The pinned `vexctl 0.4.1` is in nixpkgs today; the interesting design surface is a Nix DSL that lets users author VEX statements as attrsets and have them (a) merged into the scanner runs to suppress noise and (b) attached to the image as signed in-toto attestations for downstream consumption.

## What Changes

- New library `nix/modules/oci/security/vex/lib.nix`:
  - `mkVexDocument { author, statements = [ { vulnerability, products, status, justification, ... } ] }` returns valid OpenVEX 0.2.0 JSON-LD.
- New per-container option tree `nix/modules/oci/_oci/vex/`:
  - `enabled.nix` (bool, default false)
  - `documents.nix` (list of path-or-attrset; attrsets go through `mkVexDocument`)
  - `attach.nix` (bool, default true: attach as attestation via `mkAttestation`)
- Teach every CVE scanner script under `nix/modules/oci/security/cve/{trivy,grype,osv}/lib.nix` to accept an optional VEX document path and pass `--vex <path>` / `--openvex <path>` accordingly. Vulnix ignored (no OpenVEX support upstream).
- Register pipeline step `provenance/vex-attach` in `nix/modules/oci/pipeline/step-registrations.nix` (`phase = "post-push"`, `category = "provenance"`, `deps = [ "push" ]`).
- BDD test `nix/modules/oci/containers/_tests/vex/authoring.test.nix` verifying (a) authored VEX doc validates against the OpenVEX schema, (b) a CVE with a `not_affected` VEX statement is suppressed from trivy output, (c) the same document is attached as a referrer with `artifactType = application/vnd.openvex+json`.
- Docs: new `docs/content/how-to/openvex.md` covering the Nix DSL, the trivy/grype/osv wiring, and the sigstore-verifier verification story.

## Capabilities

### New Capabilities
- `supply-chain/openvex`: authoring and attaching OpenVEX 0.2.0 vulnerability-exploitability-exchange documents from Nix, consumed by CVE scanners at scan time and by verifiers at deploy time.

### Modified Capabilities
- `supply-chain/in-toto-attestations`: registers `openvex` as a predicate type.
- `pipeline/cve-scanning`: scanners gain optional `--vex` input.

## Impact

- Depends on `cosign-attest-in-toto-wrapper`, `oci-attach-referrer-substrate`, and `cve-osv-scanner` (for the third scanner integration; if osv change has not landed, that binding is deferred).
- `vexctl 0.4.1` already in nixpkgs; no new tool.
- Ergonomics are the design surface: attrset DSL vs raw JSON path. Both supported.
- Zero risk of breaking existing scanner runs (VEX is opt-in per document).
