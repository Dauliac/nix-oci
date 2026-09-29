# Declarative cross-class module registration

## Why

The `nix-oci` deploy stack registers identical module bodies against
three flake-parts classes (`nixos`, `homeManager`, `systemManager`) by
hand. Five files under `nix/modules/deploy/nix-oci/options/` end with
`{ flake.modules.nixos.X = mod; flake.modules.homeManager.X = mod;
flake.modules.systemManager.X = mod; }`; `nix/modules/deploy/nix-oci/compose.nix`
triplicates the same `imports = [ ... ]` list and the same
`_module.args.nix2container = ...` bridging for three classes
(78 lines, `compose.nix:27-76`). Adding or removing a sub-module means
editing three lists that must stay almost identical but differ in one
entry each - error-prone in review.

An earlier iteration of this change proposed adopting `denful/flake-aspects`
(a small third-party library that transposes `flake.aspects.<name>.<class>`
into `flake.modules.<class>.<name>`). It was implemented, then rejected:
the library's transpose primitive walks the aspect submodule config
without filtering out declared option keys (`name`, `description`,
`includes`, `provides`, `_`, `__functor`, `modules`, `resolve`), so
those names appear as fake top-level entries in `flake.modules`
alongside real class names. The pollution is inert (values are broken
modules that only fail when imported) but it corrupts the public
attribute set and can't be reported upstream (`has_issues: false` on
denful/flake-aspects). See the archived proof of concept at
`.claude/research-cache/flake-aspects-README.md` for the full analysis.

This proposal replaces that path with a **pure-data option** contributed
to `github:Dauliac/nix-lib`. Each file writes a small attrset to
`flake.crossClassModules.<name>`. A single aggregator in `nix-lib`
reads the option and emits `flake.modules.<class>.<name>` for every
declared class. No external dependency, no output pollution,
one-file-per-option preserved, and the mechanism flows entirely through
config/options (no manual imports, no helper function calls).

The nix-lib primitive lands under a separate OpenSpec change in that
repo (`openspec/changes/cross-class-modules-primitive/` in nix-lib);
this change consumes it after nix-lib ships the option.

## What Changes

- **Bump `inputs.nix-lib`** to a rev that exposes the new
  `options.flake.crossClassModules` option and its aggregator.
- **Rewrite `nix/modules/deploy/nix-oci/options/enable.nix`,
  `backend.nix`, `containers.nix`, `registry.nix`, `snapshotter.nix`**
  from three-line `flake.modules.<class>.X = mod` epilogues into
  single-attribute `flake.crossClassModules.<name>` contributions with
  `{ classes; module; }`. Asymmetric registrations (`registry`,
  `snapshotter`: nixos + systemManager only) express asymmetry as data
  in the `classes` list, not as file duplication or code branches.
- **Rewrite `nix/modules/deploy/nix-oci/compose.nix`** to a single
  `flake.crossClassModules.nix-oci` contribution with
  `{ classes; includes = [ ... sub-module names ... ]; module = shared
  bridging; }`. The aggregator filters `includes` per-class by
  intersecting each included module's own declared `classes`, so
  writing `includes = [ nix-oci-registry nix-oci-snapshotter ... ]`
  once at the composer produces the correct per-class subset
  automatically. `compose.nix` collapses from 78 lines to ~30.
- **Preserve `import-tree` and one-file-per-option conventions**: no
  file moves, no new manual imports. Each file contributes to a config
  option provided by nix-lib's `flakeModules.default` (already imported
  at `nix/flake-module.nix:12`).
- **No user-observable behavior change**: the resulting
  `flake.modules.<class>.nix-oci-*` attribute values are equivalent to
  today's. Any external consumer sees the same interface.

Two follow-up tiers are explicitly out of scope for this change and
will be tracked as separate changes: **Tier B** consolidates
`nix/modules/soci-snapshotter/deploy/{nixos,home-manager,system-manager}.nix`
(asymmetric per-class copies) via the same primitive; **Tier C**
migrates the remaining cross-class files (`load-services.nix`,
`run-services.nix`, `snapshotter-config.nix`, `test-vm.nix`,
`test-apps.nix`, etc.).

## Capabilities

This change doesn't add, remove, or modify any user-observable
capability of nix-oci itself. It restructures how internal module
registration is written while keeping the output `flake.modules.*`
attribute set equivalent to the current one. `skip_specs: true` is set
in `.openspec.yaml`. The user-facing addition (`options.flake.crossClassModules`)
belongs to the nix-lib change, not this one.

### New Capabilities

None.

### Modified Capabilities

None.

## Impact

- **Prerequisite**: nix-lib change `cross-class-modules-primitive`
  lands and is tagged/rev-published. This change bumps
  `inputs.nix-lib.rev` to that commit.
- **Affected code in this repo**:
  - `flake.nix` / `flake.lock`: bump nix-lib rev.
  - `nix/modules/deploy/nix-oci/options/enable.nix`
  - `nix/modules/deploy/nix-oci/options/backend.nix`
  - `nix/modules/deploy/nix-oci/options/containers.nix`
  - `nix/modules/deploy/nix-oci/options/registry.nix`
  - `nix/modules/deploy/nix-oci/options/snapshotter.nix`
  - `nix/modules/deploy/nix-oci/compose.nix`
- **Not affected**:
  - `flake.modules.*` output shape and values (verified via
    structural fingerprint diff before/after; see design.md
    "Migration Plan").
  - `nix/modules/oci/**` (flake-parts side): not registered per-class.
  - `nix/modules/_nixos-oci/**` (NixOS container eval): not
    class-registered by the changed files.
  - `nix/modules/soci-snapshotter/**` (Tier B, deferred).
- **No new external dependency**: `flake-aspects` isn't adopted.
  `nix-lib` was already a dependency, so the change is a rev bump.
- **Reversibility**: high. All edits are file-local; reverting the six
  files and rolling back the nix-lib rev restores prior behavior.
- **Cross-repo coordination**: this change can't land before nix-lib
  ships the primitive. The nix-lib change explicitly ships a
  `crossClassModulesTests` derivation to prove the primitive works;
  this repo bumps only after that check passes.
