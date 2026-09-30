## Context

`mkAutoLabels` lives at `nix/lib/oci.nix:393` and is called from two
sites: `nix/modules/oci/lib/mkOCIImage.nix:54` (flake-parts image
builder) and `nix/modules/deploy/nix-oci/options/_containers/image.nix:65`
(deploy path). Both pass `dependencies = oci.dependencies` today, so
the function already receives the data; only the projection is
missing. See `proposal.md - Why` for motivation.

The unit-test entrypoint is `nix/modules/oci/lib/mkAutoLabels.nix`,
which is a nix-lib test spec: `fn = pure.mkAutoLabels`, followed by an
attrset of named test cases with `args`, `expected` and `assertions`.
The existing tests exercise the "generates OCI annotations" and
"returns empty when autoLabels disabled" cases.

Docs live at `docs/content/architecture/automatic-labeling.md`. A
sibling page, `docs/content/architecture/container-metadata-wiring.md`,
also enumerates labels and must stay consistent.

## Goals / Non-Goals

**Goals**
- One additional label, `io.github.dauliac.nix-oci.nix.deps`, encoding
  the direct dependencies the user declared in `oci.dependencies`.
- Docs page enumerates every label the function can emit, in exactly
  one authoritative place, with a top-of-page matrix cross-linking to
  the per-group section.
- No new option surface, no signature change, no breaking change to
  callers.

**Non-Goals**
- Enumerating the transitive Nix closure. The SBOM pipeline
  (`nix/modules/oci/security/sbom/`) is the canonical place for the
  full closure and this change deliberately does not compete with it.
- Adding `org.opencontainers.image.source` and `.revision`. Those
  require flake `self.rev` threading and are already documented as
  user-supplied.
- Reformatting sibling docs beyond the single-line cross-reference
  needed for consistency.

## Decisions

### D1. Label shape: single JSON string, not flat structured keys

Chosen: emit one label whose value is a JSON string of the form
`[{"pname":"...","version":"...","description":"..."}, ...]`.

Rejected alternatives:

- Flat structured keys, one triple per dep (`nix.deps.<pname>.version`,
  `.description`, ...). Rejected because `pname` can contain characters
  that are awkward in OCI label keys (dots, plus, tilde), and because
  10 deps become 30 labels, which balloons manifest size and clashes
  with the registry-side soft ceiling on total label count. syft
  itself chose a single JSON label for the same reason.
- Compact CSV `pname@version,pname@version`. Rejected because it drops
  `description`, which is the field the user specifically asked to
  include.
- Two labels, one CSV of names+versions and one JSON of descriptions.
  Rejected as strictly worse than the JSON variant: same total bytes,
  harder to consume.

### D2. Source of names: user's `oci.dependencies` list, not the closure

Chosen: iterate the same `dependencies` list that already reaches the
function. This is the list the user explicitly authored, matches the
`nix.dependency-count` semantics, and stays under a bounded size.

Rejected alternative: walk `package.meta.buildInputs` or the runtime
closure via `builtins.closureInfo`. Rejected because it would (a)
introduce an IFD-shaped analysis at label-generation time, (b)
overlap directly with the syft-backed SBOM pipeline, and (c) make the
label unbounded in size for realistic containers.

### D3. Size guard: cap the JSON at 4096 bytes, truncate the list

Chosen: build the JSON, and if its length exceeds 4096 bytes, drop
the trailing elements one at a time until it fits. When truncation
happens, append a final element `{"truncated": true, "dropped": N}`
so downstream consumers can detect the condition.

Rejected alternatives:

- No guard. Rejected because Docker Hub enforces a 4KB per-label
  ceiling and would silently reject the manifest on the push path.
- Compressed / base64-gzipped payload. Rejected as overengineering:
  10-15 deps with short descriptions comfortably fit under 4KB
  uncompressed, and gzip would make `docker inspect` output opaque
  without a decoding step.

### D4. Missing meta fields degrade gracefully

Chosen: for each element, take `pname` and `version` unconditionally
(both are structurally guaranteed on any `mkDerivation`-shaped
attrset). Take `description` from `meta.description` if present;
otherwise omit the `description` key from the object rather than emit
a null. Elements without either `pname` or `version` (rare but
possible for wrapped or trivial builders) are dropped from the list
and counted in the same truncation counter as D3.

### D5. Documentation shape

Chosen: keep the existing per-namespace section structure, but add:

1. A "Complete label matrix" table at the top of the page, one row
   per label, three columns: `Label`, `Namespace section`, `Emitted
   when`. Every row's namespace column links to the anchor of the
   corresponding section.
2. A new row in the "Nix package identity" table for `nix.deps`.
3. Section headings for `security.insecure` and `provenance.source-type`
   so they appear in the matrix.
4. One new sentence in `container-metadata-wiring.md` naming
   `nix.deps` alongside the existing four `nix.*` labels.

This follows Diataxis's "Reference" mode: austere, complete,
one-line-per-fact tables. Explanation ("why") stays where it already
lives at the bottom of the page.

## Risks / Trade-offs

- **Label size on large `dependencies` lists** → D3 cap plus explicit
  truncation marker. Consumers get either the full list or a clearly
  labelled subset.
- **Docs drift the next time a label is added** → the top-of-page
  matrix table becomes the authoritative index. A tasks-level check
  (grep-based) verifies every label emitted by `mkAutoLabels` appears
  in the matrix; run in CI via the existing docs lint step or as a
  bd follow-up if not yet wired.
- **Consumers assume Docker's classic `Cmd`-style label naming and
  fail on JSON** → mitigated by keeping the label in the vendor-scoped
  `io.github.dauliac.nix-oci.*` namespace, which downstream tooling
  already treats as opaque strings. This convention mirrors syft's
  `sbom` label and cosign's signature payload labels.

## Migration Plan

No migration. Additive change; existing labels are unchanged; no
option surface change. Rolling back is `git revert`.

## Open Questions

None material to specs, approach, or task breakdown.
