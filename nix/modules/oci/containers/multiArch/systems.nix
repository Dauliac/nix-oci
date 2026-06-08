# Container multiArch.systems option
#
# Replaces `multiArch.enabled` with a systems list.
# Non-empty list implicitly enables multi-arch.
# `multiArch.enabled` is kept as a computed readOnly for backward compat.
{ lib, ... }:
let
  archDefs = import ../../../_lib/arch.nix;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { config, ... }:
        {
          options.multiArch = {
            systems = lib.mkOption {
              type = lib.types.listOf (lib.types.enum archDefs.supportedSystems);
              description = ''
                Target systems for multi-arch image building.

                When non-empty, multi-arch is enabled and the listed systems
                define which architectures will be included in the manifest.

                Uses Nix system strings (same convention as flake-parts `systems`).
              '';
              default = [ ];
              example = [
                "x86_64-linux"
                "aarch64-linux"
              ];
            };

            enabled = lib.mkOption {
              type = lib.types.bool;
              readOnly = true;
              description = "Whether multi-arch is enabled. Computed from `multiArch.systems != []`.";
              default = config.multiArch.systems != [ ];
            };
          };
        };
    };
}
