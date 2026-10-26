## Context

See proposal.md - Why. Grounding for the design:

- Cosign 3.0.6 is pinned in `flake.lock`; it supports `attest`, `attest-blob`, `--type <uri>`, and `--new-bundle-format` natively.
- The in-toto Statement v1 schema (`https://in-toto.io/Statement/v1`) requires `_type`, `subject`, `predicateType`, `predicate`. Every downstream predicate change (SLSA, OpenVEX, SCAI, zero-CVE) shares this envelope.
- The predicate URI is the only field that varies per predicate type; the envelope is identical.
- Signing key material must never be an IFD input; it is a runtime path resolved at attest-time.

## Goals / Non-Goals

**Goals:**
- One `mkAttestation { predicateType, predicate, subject }` function callable from four downstream changes without any of them reimplementing envelope construction, signing, or attach.
- Predicate-type registry (`oci.pipeline.attestations.predicateTypes.<name> = "<uri>"`) as an open attrset so downstream steps register their type without editing this library.
- Consistent stdout marker `NIX_OCI_ATTESTATION type=<uri> digest=<sha256>` so composite pipelines correlate attestations.

**Non-Goals:**
- Building predicate content (SLSA, VEX, SCAI generators live in their respective changes).
- Verifier tooling (verification is a consumer concern; the wrapper only writes attestations).
- Custom-signer support beyond cosign (e.g., gpg, x509 chains). Cosign covers keyless + keyed + hardware keys, sufficient for all downstream needs.

## Decisions

### Build the Statement in Nix, sign via cosign, attach via `mkAttachReferrer`

The Statement JSON is a small attrset built purely in Nix (`builtins.toJSON`); cosign signs the resulting file via `cosign attest --predicate <file> --type <uri> --new-bundle-format <ref>`. The resulting bundle is handed to `mkAttachReferrer` from `oci-attach-referrer-substrate` for registry-side attachment. Alternative: use `cosign attest-blob` and attach separately. Rejected because `cosign attest` already handles the attach when given an image reference, and using `attest-blob` doubles the number of network calls.

### Bundle format default: protobuf bundle (`--new-bundle-format`)

Modern verifier libraries (sigstore-python, sigstore-js, `gh attestation verify`) default to protobuf bundle. Emitting the legacy detached format would require every downstream verifier to run a shim. Cosign 3.x supports both; we opt into bundle. Composes with `sigstore-bundle-format` (which flips the same default at the image-signing layer).

### Predicate-type registry as an open attrset, not an enum

Downstream steps register their predicate type via option contribution (`oci.pipeline.attestations.predicateTypes.slsa = "https://slsa.dev/provenance/v1"`). Alternative: closed enum in this library. Rejected because it would require editing this library for every future predicate type, defeating the "shared substrate" property.

### Predicate content is opaque to the wrapper

The wrapper does not validate predicate content against the schema of the given `predicateType`. That validation lives in the downstream predicate emitter (SLSA, VEX, SCAI each own their schema conformance). Alternative: JSON-schema validation at attest time. Rejected because (a) it duplicates work the emitter should do, (b) it couples this library to every predicate schema.

### Subject shape: `subject[0].digest.sha256 = <digest>` only

The wrapper accepts a single-subject descriptor with `name` and `digest`. Multi-subject attestations (attesting a set of images at once) are not in scope; every downstream use case attests a single image.

## Risks / Trade-offs

- **Sigstore bundle format churn** -> bundle format is at v0.3 (`application/vnd.dev.sigstore.bundle.v0.3+json`) and considered stable by sigstore; if the format bumps, we bump the wrapper in one place. Contained blast radius.
- **Predicate schema drift** -> the wrapper is intentionally schema-agnostic; downstream steps own their predicate schema conformance.
- **Key material handling** -> keyless (Fulcio) is the default path in CI; keyed path requires a runtime file path (never IFD). Documented.
- **Rekor rate limits** -> keyless signing publishes to Rekor which has per-source rate limits. For high-frequency emit, we can point at a self-hosted Rekor; documented as an operational consideration.

## Migration Plan

1. Depends on `oci-attach-referrer-substrate` landing first (`mkAttachReferrer`).
2. Ship the wrapper alongside a smoke-test BDD (fake predicate) so it exercises attest+attach on a synthetic image.
3. Downstream changes (SLSA, VEX, SCAI, GH attestations) migrate from ad-hoc `cosign attest` calls (if any exist in transit) to `mkAttestation`.

## Open Questions

None material.
