## 1. Core function change

- [ ] 1.1 In `nix/lib/oci.nix`, inside the `mkAutoLabels` `let` block,
      compute `depsMeta` by mapping the `dependencies` list to
      `{ pname, version, description }` objects, dropping elements
      that lack `pname` or `version`. Verify with `nix eval --impure
      --expr 'import ./nix/lib/oci.nix { lib = (import <nixpkgs> {}).lib; }'`
      that the module still evaluates.

- [ ] 1.2 In the same file, encode `depsMeta` to JSON via
      `builtins.toJSON`, apply the 4096-byte cap by trimming the
      trailing elements and appending a `{ truncated = true; dropped = N; }`
      marker when the cap is hit. Verify by hand with a synthetic
      list of 200 fake deps in a scratch expression that the output
      length stays below 4097 bytes and the marker is present.

- [ ] 1.3 In the `nixIdentity` attrset (around line 535), add a
      conditional entry `"${ns}.nix.deps" = <json>` guarded by
      `lib.optionalAttrs (dependencies != [ ])`. Verify by running
      `nix build .#packages.<system>.default-oci-image` on the
      `basics/nginx-01` example (or the nearest one) and inspecting
      the resulting image with `skopeo inspect --raw` for the
      presence of the label.

## 2. Unit tests

- [ ] 2.1 In `nix/modules/oci/lib/mkAutoLabels.nix`, extend the
      `"generates OCI annotations"` test case with two extra
      assertions: `nix.dependency-count == "0"` is absent, and
      `nix.deps` is absent (the args in that test have no
      `dependencies`). Verify by running the nix-lib test runner
      (`nix flake check` or the specific check attr, whichever is
      wired in this repo) and seeing the case pass.

- [ ] 2.2 Add a new test case `"emits nix.deps when dependencies non-empty"`
      with `args.dependencies = [ { pname = "libA"; version = "1.0";
      meta.description = "A lib"; } { pname = "libB"; version = "2.0";
      meta.description = "B lib"; } ]` and assertions that (a)
      `nix.deps` is present, (b) `builtins.fromJSON result."io.github.dauliac.nix-oci.nix.deps"`
      is a list of length 2, (c) the first element has
      `pname = "libA"` and `description = "A lib"`, (d) list order
      matches input order. Verify by running the same test runner.

- [ ] 2.3 Add a test case `"omits nix.deps when dependencies empty"`
      with `args.dependencies = [ ]` and assertion that
      `result ? "io.github.dauliac.nix-oci.nix.deps" == false`.
      Verify via the test runner.

- [ ] 2.4 Add a test case `"nix.deps tolerates missing description"`
      with a dep whose `meta` has no `description`, asserting the
      element still appears in the JSON with `pname` and `version`
      and no `description` key. Verify via the test runner.

- [ ] 2.5 Add a test case `"nix.deps caps payload at 4KB"` with a
      synthetic list of 200 fake deps whose descriptions are 100
      chars each, asserting the resulting label value is at most
      4096 bytes long and the last decoded element has
      `truncated = true`. Verify via the test runner.

## 3. Documentation rewrite

- [ ] 3.1 In `docs/content/architecture/automatic-labeling.md`, add
      a "Complete label matrix" table immediately after the
      introductory paragraph (before "OCI standard annotations"),
      with columns `Label`, `Group`, `Emitted when`. Populate one
      row per label the code can emit, with anchor links to the
      per-group section for the middle column. Verify by rendering
      the docs site (`nix run .#docs-serve` or the equivalent
      configured task) and confirming every anchor resolves.

- [ ] 3.2 In the "Nix package identity" section of the same file,
      add a row for `nix.deps` documenting its JSON schema and the
      4KB truncation behaviour with a short example. Verify against
      the top-of-page matrix that the new row is also linked from
      there.

- [ ] 3.3 Add H3 subsection headings for `security.insecure` and
      `provenance.source-type` under the "Nixpkgs security metadata"
      section so they appear in the matrix as first-class rows.
      Verify by grepping the file for `^### ` and comparing against
      the matrix rows.

- [ ] 3.4 In `docs/content/architecture/container-metadata-wiring.md`
      add `nix.deps` to the label mapping table (around line 238)
      with source `oci.dependencies` and example
      `'[{"pname":"openssl",...}]'`. Verify the two docs pages list
      the same set of labels via a `grep -c "nix.deps" docs/content/architecture/*.md`
      count of exactly 2.

## 4. Validation

- [ ] 4.1 Run `openspec validate auto-labels-deps-and-docs --strict`
      and see zero errors.

- [ ] 4.2 Run the mise quality gates that this repo declares
      (`mise run fix`, `mise run lint`, `mise run build`, `mise run test`
      for whichever are declared) and see all green. This is the
      final gate before proposing to close the change out.
