# Pure-eval assertion path for BDD specs.
#
# `level = "eval"` is documented in `_option-test-spec.nix` as "container
# config evaluates without error (cheapest)". Nothing ever read those
# specs: `test-vm.nix` keeps only `runtime` and `deploy` and discards the
# rest, so every eval-level spec was declared, reviewed and committed
# while never executing. `nix eval .#tests` returned only the nix-lib
# function tests, never a spec.
#
# This module gives them a reader. For each eval-level spec it forces:
#
#   1. The BDD narrative strings. Several specs interpolate a regression
#      guard into `then` -- see `_tests/invariant/_helpers.nix` and the
#      coherence-*.test.nix files, which wrap a module eval in
#      `builtins.tryEval` and `throw` when an assertion stops firing.
#      Their own comments say this "surfaces at `nix eval .#tests`",
#      which it never did, because nothing forced the string. Forcing it
#      here is what finally makes those guards fire.
#
#   2. The container config, evaluated through the SAME submodule type
#      real containers use (`oci.perContainer`). These containers are
#      deliberately NOT added to `oci.containers`: that attrset drives
#      the `bdd-app-*` CI matrix, and an eval-level spec is explicitly
#      not an image to build.
#
# Scope: eval-level only. `build` (103 specs) and `inspect` (40) assert
# strictly more than evaluation -- that an image builds, and that its
# contents are what we expect -- so they need a build or a VM and are
# deliberately left to follow-up work rather than quietly redefined as
# "it evaluated".
#
# No IFD: this is all evaluation. The derivation is a `touch $out` whose
# inputs are strings that are already fully evaluated by the time Nix
# can instantiate it, which is exactly what makes instantiation the
# assertion.
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      lib,
      ...
    }:
    {
      options.test.oci._evalSpecContainers = lib.mkOption {
        # Same submodule type as `oci.containers`, so a spec's container
        # is type-checked and evaluated exactly like a real one.
        type = lib.types.attrsOf config.oci.perContainer;
        internal = true;
        default = { };
        description = ''
          Internal: containers from `level = "eval"` specs, evaluated
          through the real per-container submodule type but kept out of
          `oci.containers` so they never enter the bdd-app matrix.
        '';
      };

      options.test.oci._specEvalCheck = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        internal = true;
        default = null;
        description = ''
          Internal: aggregate check whose INSTANTIATION forces every
          eval-level spec. Wired into `checks.<system>.spec-eval` by the
          root flake.
        '';
      };
    }
  );

  config.perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Mirrors extractVmSpecs in test-vm.nix, for the level it drops.
      evalSpecs = lib.concatMapAttrs (
        group: scenarios:
        lib.concatMapAttrs (
          name: spec: if spec.level == "eval" then { "${group}--${name}" = spec; } else { }
        ) scenarios
      ) (config.test.oci.perContainer or { });

      parkedSpecs = lib.filterAttrs (_: spec: (spec.parked or null) != null) evalSpecs;
      liveSpecs = lib.filterAttrs (_: spec: (spec.parked or null) == null) evalSpecs;

      # Only unparked specs get a container. A parked spec names a
      # concrete blocker that stops its container evaluating at all
      # (see the `parked` option), so evaluating it would just
      # re-discover the blocker on every CI run.
      specContainers = lib.mapAttrs (_: spec: spec.container) liveSpecs;

      # Forcing this string is the assertion. Every interpolation below
      # has to be evaluated before Nix can produce the derivation, so a
      # spec whose narrative guard throws, or whose container config
      # fails to evaluate, makes `spec-eval` fail to instantiate.
      #
      # Parked specs still contribute their narrative, so a regression
      # guard interpolated into `then` keeps firing even while the
      # container half is skipped.
      narrative =
        key: spec: "${key}\n  given: ${spec.given}\n  when:  ${spec."when"}\n  then:  ${spec."then"}";

      forcedReport = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          key: spec:
          let
            # `_checks` is the repo's own force-evaluated assertion
            # surface for a container (see nixos-integration.nix).
            containerChecks = config.test.oci._evalSpecContainers.${key}.nixosConfig._checks or "";
          in
          "${narrative key spec}\n  checks: ${containerChecks}"
        ) liveSpecs
        ++ lib.mapAttrsToList (key: spec: "${narrative key spec}\n  PARKED: ${spec.parked}") parkedSpecs
      );
    in
    {
      test.oci._evalSpecContainers = specContainers;

      test.oci._specEvalCheck = lib.mkIf (evalSpecs != { }) (
        pkgs.runCommand "nix-oci-spec-eval"
          {
            inherit forcedReport;
            liveCount = builtins.toString (builtins.length (builtins.attrNames liveSpecs));
            parkedCount = builtins.toString (builtins.length (builtins.attrNames parkedSpecs));
            passAsFile = [ "forcedReport" ];
          }
          ''
            mkdir -p "$out"
            cp "$forcedReportPath" "$out/report.txt"
            echo "eval-level BDD specs: $liveCount executed, $parkedCount parked" > "$out/summary.txt"
          ''
      );
    };
}
