# Design: declarative-cross-class-modules

## Context

See `proposal.md - Why` for motivation. Design-relevant facts about
the current state and about the rejected alternative:

- **Discovery**: `import-tree` (input `denful/import-tree`) walks
  `nix/modules/**/*.nix` and imports every non-underscore-prefixed
  file into `flake.imports`. Files register flake-parts modules;
  today they mostly write `flake.modules.<class>.<name> = mod`.
- **nix-lib is already an input**: `flake.nix:18-21` pulls
  `github:Dauliac/nix-lib`; `nix/flake-module.nix:12` imports its
  `flakeModules.default`, which autodiscovers every option module
  under `modules/nix-lib/` via its own vendored import-tree
  (`internal-dendritic-import-tree` change in nix-lib, landed).
  That means: any option declared in a new file
  `modules/nix-lib/cross-class-modules.nix` in the nix-lib repo
  becomes available in this repo the instant `inputs.nix-lib`
  is bumped. No new import wiring needed on the nix-oci side.
- **Class asymmetry, not just triplication**: `registry.nix` and
  `snapshotter.nix` are registered on `nixos` and `systemManager`
  only. `enable.nix`, `backend.nix`, `containers.nix` on all three.
  `compose.nix:45-58` reflects this by omitting `nix-oci-registry`
  and `nix-oci-snapshotter-config` from the homeManager import list.
  Any redesign must express this asymmetry declaratively, not by
  flattening it or hand-coding per-class exceptions.
- **`compose.nix` inputs threading**: each per-class body sets
  `_module.args.nix2container = inputs.nix2container.packages.${pkgs.system}.nix2container`
  and `_module.args.nixLibNixosModule = inputs.nix-lib.nixosModules.default`.
  Both lines appear three times, byte-identical.
- **Rejected alternative - flake-aspects**: `.claude/research-cache/flake-aspects-README.md`
  captures the research. The library's transpose (upstream
  `nix/default.nix` + `nix/types.nix` at pinned SHA
  `e5bbf7be955e8289d545c783673808b18d48c780`) walks the aspect
  submodule config with `lib.mapAttrsToList`, emitting entries for
  every top-level attribute of every aspect. The aspect submodule
  declares seven options (`name`, `description`, `includes`,
  `provides`/`_`, `__functor`, `modules`, `resolve`); the transposer
  can't distinguish declared options from freeform class cells, so
  `flake.modules` ends up with fake top-level keys
  `[ _ __functor description includes modules name provides resolve ]`
  alongside real class names. Verified empirically:
  `nix eval .#modules --apply builtins.attrNames` after importing
  `flake-aspects.flakeModule` and defining one aspect returned the
  polluted set. The pollution is inert but public. Upstream has
  `has_issues: false`, so no bug report path.

## Goals / Non-Goals

**Goals:**

- Eliminate the per-class `flake.modules.<class>.X = mod` epilogues in
  the five Tier-A option files (each `mod` written once, class fan-out
  expressed as pure data).
- Collapse the three per-class blocks in `compose.nix` into one
  contribution to `flake.crossClassModules.nix-oci`.
- Preserve the output shape of `flake.modules.nixos.nix-oci`,
  `flake.modules.homeManager.nix-oci`, and
  `flake.modules.systemManager.nix-oci`. Structural fingerprint of
  `flake.modules` (attribute-name tree) unchanged; behavioral
  equivalence guarded by `bdd-vm` and `bdd-apps`.
- Preserve class asymmetry declaratively: `registry` and `snapshotter`
  atomic files list `classes = [ nixos systemManager ]`; the composer's
  `includes` list contains them unconditionally; the aggregator drops
  them on `homeManager` because the atomic module's own `classes` does
  not include HM.
- Fit the repo conventions: (a) libs live in `github:Dauliac/nix-lib`,
  not local `nix/lib/`; (b) modules are discovered by `import-tree`,
  never imported by hand; (c) contributions flow through
  config/options only, never through function calls.
- Zero pollution of the `flake.modules` output.

**Non-Goals:**

- Migrating any file outside the six listed in `proposal.md - Impact`.
- Adding a dependency-graph / `includes` DAG feature richer than the
  simple per-class filter described above. Tier C can revisit.
- Reorganizing `nix/modules/`.
- Writing docs beyond the OpenSpec artifacts. Architecture-doc
  reconciliation is a follow-up change gated on Tier C landing.

## Decisions

### D1 - Primitive lives in nix-lib, contributed via option

**Chosen**: the option `flake.crossClassModules` and its aggregator
are declared in a new file `modules/nix-lib/cross-class-modules.nix`
in the nix-lib repo. Autodiscovered by nix-lib's import-tree; exposed
to consumers through `inputs.nix-lib.flakeModules.default` (already
imported at `nix/flake-module.nix:12`). No import statement changes in
this repo.

**Alternatives considered:**
- Local `nix/lib/multiClassModule.nix` helper called via `import`.
  Rejected: violates the "libs in nix-lib" convention, forces each
  option file to grow an `import ../../../../lib/...` line
  (violates the "no manual imports" convention), and passes the class
  list through a function call (violates the "config/options only"
  convention).
- Third-party `denful/flake-aspects`. Rejected: pollutes
  `flake.modules` (see Context).

**Consequence**: this change has a hard cross-repo dependency. It can't
land before the nix-lib change ships. Coordination is captured in
`tasks.md - 1.x`.

### D2 - Option schema

**Chosen**:

```nix
options.flake.crossClassModules = lib.mkOption {
  default = { };
  description = "Deferred modules registered on multiple flake.modules.<class> keys, declared as pure data.";
  type = lib.types.attrsOf (lib.types.submodule {
    options = {
      classes  = lib.mkOption { type = lib.types.listOf lib.types.str; };
      module   = lib.mkOption { type = lib.types.deferredModule; default = { }; };
      includes = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
    };
  });
};
```

- `classes`: which `flake.modules.<class>` keys receive the entry.
- `module`: the deferred module body registered on each class. Same body
  for every class in the symmetric case; distinct
  `crossClassModules.<name>` entries for genuinely different bodies.
- `includes`: names of other `crossClassModules.<n>` whose class-cell
  the aggregator merges into this one. Used only by composer entries
  (for example `nix-oci` composes `nix-oci-enable`, `nix-oci-backend`, ...).
- No `defaultFunctor`, `provides`, or DAG features. Kept minimal on
  purpose - Tier A doesn't need them.

### D3 - Aggregator semantics: per-class include filtering as data

**Chosen**: the aggregator emits, for each `crossClassModules.<name>`
and each `class` in its `classes`, an entry
`flake.modules.<class>.<name> = { imports = [ def.module ] ++ (map
lookup (filter (n: class in crossClassModules.<n>.classes) def.includes)) }`.

That's: the composer says `includes = [ nix-oci-registry ... ]`
unconditionally; the aggregator drops names whose own `classes` does
not include the target class. Asymmetry is expressed once (at the
atomic file's `classes` list) and propagates correctly through the
composer without per-class branching.

**Alternative considered**: `includes` as `functionTo (listOf str)`
receiving `{ class }` so the composer author writes per-class logic.
Rejected because it re-introduces exactly the per-class branching we
are trying to eliminate.

### D4 - Composer entry pattern for compose.nix

**Chosen**: the composer entry is itself a `crossClassModules.<name>`
whose `includes` names the sub-modules to compose and whose `module`
carries only shared bridging (the two `_module.args.*` lines). The
aggregator does the fan-out and per-class filtering.

```nix
{ inputs, ... }: {
  flake.crossClassModules.nix-oci = {
    classes = [ "nixos" "homeManager" "systemManager" ];
    includes = [
      "nix-oci-enable" "nix-oci-backend" "nix-oci-containers"
      "nix-oci-registry" "nix-oci-snapshotter" "nix-oci-snapshotter-config"
      "nix-oci-load-services" "nix-oci-run-services" "soci-snapshotter"
    ];
    module = { pkgs, ... }: {
      _module.args.nix2container    = inputs.nix2container.packages.${pkgs.system}.nix2container;
      _module.args.nixLibNixosModule = inputs.nix-lib.nixosModules.default;
    };
  };
}
```

**Sub-modules referenced in `includes` that are NOT migrated in
Tier A** (`nix-oci-load-services`, `nix-oci-run-services`,
`nix-oci-snapshotter-config`, `soci-snapshotter`) still exist as
`flake.modules.<class>.<n>` entries written by their own files.
Because the aggregator's per-class filter looks them up in
`config.flake.modules.${class}.${n}` (not
`config.flake.crossClassModules.${n}.classes`), the fallback path for
non-migrated names must be: **if the name isn't present in
`crossClassModules`, look it up in the module tree directly and
include it on every class listed by the composer**. Written explicitly
in the aggregator:

```nix
imports = [ def.module ] ++ map
  (n: config.flake.modules.${class}.${n} or (throw "unknown ${n} on ${class}"))
  (filter (n:
    let cm = config.flake.crossClassModules.${n} or null;
    in cm == null || builtins.elem class cm.classes
  ) def.includes);
```

If the sub-module is migrated: filter by its declared `classes`.
If the sub-module isn't migrated (no `crossClassModules` entry):
include it unconditionally (the underlying module either exists on
this class or fails at lookup time, matching the current behavior).

This gives clean interop during the tier rollout: after Tier A, the
composer's `includes` mixes migrated and non-migrated names; after
Tier B/C all names are migrated and the fallback branch is dead code
that can be removed.

### D5 - No new option in this repo

**Chosen**: this repo declares zero new options. Every option file
contributes to `flake.crossClassModules.<name>` provided by nix-lib.

**Consequence**: `.openspec.yaml` sets `skip_specs: true` here. The
specs-worthy artifact (the `crossClassModules` option) is documented
in the nix-lib change's own spec / design.

## Risks / Trade-offs

- **Cross-repo coordination cost** → mitigation: strict sequencing.
  Task 1.x block on the nix-lib rev landing and its test derivation
  passing. This repo bumps `inputs.nix-lib` only after that.
- **Interop period during tier rollout** → mitigation: D4's fallback
  branch handles non-migrated `includes` names. Reviewed as intentional
  transitional code; scheduled for removal at the end of Tier C.
- **Structural fingerprint drift** → mitigation: capture
  `nix eval .#modules --apply 'mods: builtins.mapAttrs (_: cls:
  builtins.attrNames cls) mods' --json` before the migration; the
  post-migration output must be byte-identical.
- **Functional behavior drift beyond fingerprint** → mitigation: run
  `bdd-vm` and `bdd-apps` checks; either fail is a hard block.
- **Attempt to write to `flake.modules.<class>.<name>` from a
  crossClassModules-declared name in a different file will silently
  merge**. Not a regression (that's how flake-parts works today), but
  worth documenting for future authors. Add a one-line note in the
  first migrated file.

## Migration Plan

1. **Wait** for nix-lib change `cross-class-modules-primitive` to land
   with its test derivation green. Note the rev.
2. **Bump `inputs.nix-lib`** in `flake.nix` / `flake.lock` to that rev.
   Snapshot the baseline fingerprint:
   `nix eval .#modules --apply 'mods: builtins.mapAttrs (_: cls:
   builtins.attrNames cls) mods' --json | jq -S > openspec/changes/declarative-cross-class-modules/tmp/before.json`.
3. **Migrate the five atomic option files one at a time**, running
   the fingerprint diff after each. Files, in order of migration
   (smallest first, ends with largest / most-referenced):
   `enable.nix` → `backend.nix` → `containers.nix` → `registry.nix`
   → `snapshotter.nix`.
4. **Migrate `compose.nix`**. Fingerprint diff must remain empty.
5. **Run `bdd-vm` and `bdd-apps` checks** as the behavioral gate.
6. **Delete `openspec/changes/declarative-cross-class-modules/tmp/`**.
   File follow-up beads for Tier B / Tier C.

## Open Questions

None. The interop fallback (D4) has an intentional shape and lands with
the change; its removal is a Tier C task, not an open question.
