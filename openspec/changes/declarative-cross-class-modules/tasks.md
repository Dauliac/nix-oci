## 1. Prerequisite: nix-lib primitive landed

- [ ] 1.1 Confirm nix-lib change `cross-class-modules-primitive` is merged and cut on a rev (see `<nix-lib>/openspec/changes/cross-class-modules-primitive/`). Note the rev SHA. Verify with `gh api repos/Dauliac/nix-lib/commits/<sha>` returns 200 and the commit touches `modules/nix-lib/cross-class-modules.nix`.
- [ ] 1.2 Verify the primitive works on that rev: `nix eval --refresh github:Dauliac/nix-lib/<sha>#flake.modules --apply builtins.attrNames` returns real class names only, and any test derivation the nix-lib change ships (for example `nix build github:Dauliac/nix-lib/<sha>#checks.x86_64-linux.crossClassModulesTests`) passes.

## 2. Bump input and snapshot baseline

- [ ] 2.1 Update `inputs.nix-lib` in `flake.nix` and refresh the lock: `nix flake update nix-lib`. Verify with `nix flake metadata --json | jq '.locks.nodes["nix-lib"].locked.rev'` matches the target SHA.
- [ ] 2.2 Snapshot the fingerprint: `mkdir -p openspec/changes/declarative-cross-class-modules/tmp && nix eval .#modules --apply 'mods: builtins.mapAttrs (_: cls: builtins.attrNames cls) mods' --json | jq -S > openspec/changes/declarative-cross-class-modules/tmp/before.json`. Verify with `jq 'keys' openspec/changes/declarative-cross-class-modules/tmp/before.json` shows exactly `[ "flake" "homeManager" "nixos" "nixos-oci" "systemManager" ]` and no pollution keys.
- [ ] 2.3 Confirm `flake.crossClassModules` option is now visible in this repo's evaluation: `nix eval .#flake --apply 'f: f ? crossClassModules'` returns `true`.

## 3. Migrate atomic option files (fingerprint-gated)

- [ ] 3.1 Rewrite `nix/modules/deploy/nix-oci/options/enable.nix` to contribute `flake.crossClassModules.nix-oci-enable = { classes = [ "nixos" "homeManager" "systemManager" ]; module = { lib, ... }: { options.oci.enable = lib.mkEnableOption "..."; }; };` with the same option body as today. Verify with `nix eval .#modules --apply 'mods: builtins.mapAttrs (_: cls: builtins.attrNames cls) mods' --json | jq -S | diff -u openspec/changes/declarative-cross-class-modules/tmp/before.json -` produces no output.
- [ ] 3.2 Rewrite `nix/modules/deploy/nix-oci/options/backend.nix` using the same pattern. Verify with the same fingerprint diff (still empty).
- [ ] 3.3 Rewrite `nix/modules/deploy/nix-oci/options/containers.nix`. `containers.nix` currently declares two options (`oci.perContainer` and `oci.containers`) inside its `mod`; keep the `mod` body byte-identical, only the epilogue changes. Verify with the same fingerprint diff.
- [ ] 3.4 Rewrite `nix/modules/deploy/nix-oci/options/registry.nix` with `classes = [ "nixos" "systemManager" ]` (HM absent, matching current asymmetry). Verify with the same fingerprint diff and additionally check the HM class does NOT gain a `nix-oci-registry` entry: `nix eval .#modules.homeManager --apply 'x: x ? nix-oci-registry'` returns `false`.
- [ ] 3.5 Rewrite `nix/modules/deploy/nix-oci/options/snapshotter.nix` with `classes = [ "nixos" "systemManager" ]`. Verify with the same fingerprint diff and the same HM-absence check for `nix-oci-snapshotter`.

## 4. Migrate compose.nix

- [ ] 4.1 Refactor `nix/modules/deploy/nix-oci/compose.nix` to a single contribution to `flake.crossClassModules.nix-oci` with `classes = [ "nixos" "homeManager" "systemManager" ]`, `includes = [ ... ]` naming every sub-module (migrated + not-yet-migrated), and `module = { pkgs, ... }: { _module.args.nix2container = ...; _module.args.nixLibNixosModule = ...; }`. Preserve the `flake.modules.nixos-oci` export line as-is. Verify with the fingerprint diff from 2.2 remaining empty.
- [ ] 4.2 Confirm the new `compose.nix` is smaller: `wc -l nix/modules/deploy/nix-oci/compose.nix` reports fewer non-comment lines than the current pre-change file. Hard failure if it grew.

## 5. Regression guard on real workloads

- [ ] 5.1 Run `nix build .#checks.x86_64-linux.bdd-vm .#checks.x86_64-linux.bdd-apps` and verify both pass. If any regresses, revert the specific migration commit that introduced it.
- [ ] 5.2 Run `nix flake show 2>&1 | grep -Ev '^\s*$|evaluating|xi show'` and verify the top-level attribute set is unchanged from a pre-migration snapshot. Any changes must be cosmetic (attribute-key ordering) or explicitly expected.
- [ ] 5.3 Delete the fingerprint baseline: `rm -rf openspec/changes/declarative-cross-class-modules/tmp/`. Verify with `test ! -d openspec/changes/declarative-cross-class-modules/tmp`.

## 6. Wrap-up

- [ ] 6.1 Add a one-line comment at the top of `compose.nix` pointing at `openspec/changes/declarative-cross-class-modules/design.md` for context on the mixed idiom (migrated + non-migrated names in `includes`).
- [ ] 6.2 Update `MEMORY.md` with a short entry noting Tier A is landed via `flake.crossClassModules`, that the primitive lives in nix-lib, and that Tiers B/C remain deferred to follow-up changes. Verify the entry appears in the index.
- [ ] 6.3 File follow-up beads: (a) Tier B - consolidate `nix/modules/soci-snapshotter/deploy/{nixos,home-manager,system-manager}.nix` into one `crossClassModules.soci-snapshotter` contribution; (b) Tier C - migrate the remaining cross-class files and remove the D4 fallback branch from the nix-lib aggregator. Verify with `bd list --labels change:declarative-cross-class-modules` shows both follow-ups.
