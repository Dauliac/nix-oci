## Why

`nix/modules/oci/security/sbom/lib.nix:38` invokes syft with `--output cyclonedx-json=<path>` and no schema-version pin. Syft's default schema version drifts across releases (the pinned `syft 1.38.0` currently defaults to CycloneDX 1.6 but a future syft could shift). The SBOM output shape is a stable interface for downstream consumers (GUAC ingest, VEX cross-reference, signing subject); pinning the format is a two-line fix that removes silent drift and lets us take advantage of CycloneDX 1.6 features (notably the `cryptographic-asset` component type for post-quantum audits and FIPS inventories).

The exploration report also flagged SPDX 3.0 emit; syft 1.38 does not yet ship SPDX 3.0 output, so that portion is a watching-brief only (documented, not wired).

## What Changes

- Add per-container option file `nix/modules/oci/_oci/sbom/syft/spec-version.nix` with enum `"1.5" | "1.6"`, default `"1.6"`.
- Thread the pin into the syft invocation in `nix/modules/oci/security/sbom/lib.nix` as `-o cyclonedx-json@<version>=<path>`.
- Optional per-container option file `nix/modules/oci/_oci/sbom/syft/spdx-version.nix` scaffolded but wired to a no-op with an assertion "SPDX 3.0 emit pending syft upstream; tracked at <upstream issue>". This lets consumers see the future switch without failing eval today.
- BDD test in `nix/modules/oci/containers/_tests/sbom/cyclonedx-version.test.nix` asserting the emitted SBOM has `specVersion == "1.6"` and (when a crypto component is present in the closure) that at least one `component.type == "cryptographic-asset"` is emitted.
- Doc update: `docs/content/security/vulnerability-scanning.md` (SBOM section) gains a "Schema version" callout.

## Capabilities

### New Capabilities
- `supply-chain/sbom-generation`: SBOM emission via syft with pinnable output schema (CycloneDX 1.5/1.6, SPDX 2.3/3.0 when upstream ready).

### Modified Capabilities
None.

## Impact

- No new dependencies; syft 1.38.0 (pinned) fully supports CycloneDX 1.6.
- Downstream SBOM consumers (VEX cross-reference, GUAC ingest) get the richer `cryptographic-asset` component type without opting in.
- SBOM byte-shape may differ from prior emit (new fields present); consumers pinning to CycloneDX 1.5 stay on the old schema via the option.
- Zero risk of build failure: the schema-version flag is purely additive on syft's CLI.
