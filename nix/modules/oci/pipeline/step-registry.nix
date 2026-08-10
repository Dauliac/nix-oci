# Pipeline step registry.
#
# Declares `oci.pipeline.steps` — the open registry where tools
# register themselves. The pipeline composer reads this to generate
# gate derivations and Taskfile JSON.
#
# Also declares `oci.pipeline.defaultBackend` — global toggle for
# probe backend routing (vm vs daemon).
{
  lib,
  flake-parts-lib,
  ...
}:
let
  stepSpecType = import ./_step-spec.nix { inherit lib; };
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { ... }:
    {
      options.oci.pipeline = {
        steps = lib.mkOption {
          type = lib.types.attrsOf stepSpecType;
          default = { };
          description = ''
            Registry of pipeline steps contributed by tool lib.nix files.

            Each step has: phase, category, backend, deps, isEnabled,
            mkStamp (for build-time gate), mkScript (for Taskfile).

            Adding a new tool = one registration. The pipeline composer
            picks it up automatically.
          '';
        };

        defaultBackend = lib.mkOption {
          type = lib.types.enum [
            "vm"
            "daemon"
          ];
          default = "vm";
          description = ''
            Default backend for probe-phase steps:
            - `"vm"` — probes run as NixOS VM derivations (build-time gate).
            - `"daemon"` — probes run as scripts in the Taskfile (runtime).

            Individual steps can override via `oci.pipeline.steps.<name>.backend`.
          '';
        };

        envVars = {
          registry = lib.mkOption {
            type = lib.types.str;
            default = "NIX_OCI_REGISTRY";
            description = "Env var name for the target registry.";
          };
          registryFallback = lib.mkOption {
            type = lib.types.str;
            default = "CI_REGISTRY_IMAGE";
            description = "Fallback env var for registry (GitLab compat).";
          };
          reportDir = lib.mkOption {
            type = lib.types.str;
            default = "NIX_OCI_REPORT_DIR";
            description = "Env var name for the report output directory.";
          };
          pushedTag = lib.mkOption {
            type = lib.types.str;
            default = "NIX_OCI_PUSHED_TAG";
            description = "Stdout marker for pushed tag output.";
          };
        };
      };
    }
  );
}
