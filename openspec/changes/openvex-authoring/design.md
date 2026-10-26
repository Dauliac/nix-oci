## Context

See proposal.md - Why. Grounding:

- OpenVEX 0.2.0 JSON-LD schema (`https://openvex.dev/ns/v0.2.0`) defines `@context`, `@id`, `author`, `role`, `timestamp`, `statements[]`; each statement has `vulnerability` (id, name, description), `products` (list of purl or oci refs), `status` (`not_affected` | `affected` | `fixed` | `under_investigation`), `justification` (enum for `not_affected`), `impact_statement` (free text).
- Trivy accepts `--vex <path>` (single doc) or a directory of VEX files.
- Grype accepts `--vex <path>`.
- OSV-Scanner accepts `--vex <path>` (recent versions).
- `vexctl 0.4.1` is pinned in nixpkgs; it builds and validates OpenVEX documents.

## Goals / Non-Goals

**Goals:**
- A DSL that lets maintainers author VEX statements as Nix attrsets, with schema validation at eval time (not at `vexctl` runtime).
- One VEX document per authoring call, aggregated across statements for a single container.
- Scanner integration: every CVE step (trivy, grype, osv) picks up the effective VEX set automatically.
- Attestation: the aggregated document is attached as an OCI referrer via the shared cosign wrapper.

**Non-Goals:**
- Multi-container aggregate VEX (org-wide VEX repository). Each container gets its own document.
- VEX authoring UI. This is a Nix-attrset DSL only.
- VEX consumption for vulnix. Vulnix has no upstream OpenVEX support; documented; skip.

## Decisions

### Nix attrset DSL: attrsets go through `mkVexDocument`, paths are pre-authored

`oci.container.vex.documents` accepts a list of paths or attrsets. Attrsets are wrapped through `mkVexDocument { author, statements }`; paths are treated as pre-authored JSON. Alternative: attrsets only. Rejected because operators sometimes ship VEX authored by a separate SBOM/vex service and want to include it verbatim.

### `status = "not_affected"` requires `justification`

The DSL asserts at eval time that a `not_affected` statement has one of the OpenVEX-enumerated justifications (`component_not_present`, `vulnerable_code_not_present`, `vulnerable_code_not_in_execute_path`, `vulnerable_code_cannot_be_controlled_by_adversary`, `inline_mitigations_already_exist`). This catches malformed statements before `vexctl` runs. Alternative: defer to `vexctl` validation. Rejected because eval-time errors are cheaper and clearer than runtime shell failures.

### `products[]` derived from the image identity by default

If a statement's `products` list is not set, the DSL populates it with a `pkg:oci/<image-name>@<tag>` purl derived from the container config, so authors do not repeat themselves for every statement. Alternative: require explicit `products[]`. Rejected because the ergonomic win is significant and the default is unambiguous.

### Scanner integration via `--vex <path>`

Each scanner step gets a small extension: when `oci.container.vex.documents` is non-empty, the emitted VEX file is passed via the scanner's native `--vex` flag. Alternative: post-filter scanner output through vexctl. Rejected because native consumption is cleaner and preserves scanner metadata.

### Attach as attestation, not as bare referrer

The document is signed via `mkAttestation` and attached as a referrer with `artifactType = "application/vnd.openvex+json"`. Alternative: attach as a bare referrer with no attestation envelope. Rejected because downstream verifier tooling expects signed VEX; a bare document has no provenance.

## Risks / Trade-offs

- **VEX authoring drift** -> DSL evolves with the OpenVEX spec; version pinned via `oci.container.vex.specVersion = "0.2.0"`.
- **Scanner behavior drift** -> Each scanner interprets `not_affected` slightly differently in its output shape. BDD tests exercise all three scanners against the same VEX document to catch regressions.
- **False negatives** if a maintainer writes an incorrect `not_affected` -> VEX is a claim, not a proof. The maintainer owns the accuracy of the claim; the pipeline emits it, does not validate the underlying fact.

## Migration Plan

1. Depends on `cosign-attest-in-toto-wrapper`, `oci-attach-referrer-substrate`, and (for the third-scanner binding) `cve-osv-scanner`.
2. Ship with `enabled = false` default; consumers author their first VEX statement, enable the feature, verify the finding disappears from trivy/grype/osv output.
3. Documentation includes a template showing how to justify each of the five OpenVEX enum values with a concrete example.

## Open Questions

None material.
