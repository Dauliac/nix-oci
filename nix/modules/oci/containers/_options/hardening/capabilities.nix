# Shared: Linux capability restrictions.
#
# Capabilities partition root's monolithic privilege into distinct units.
# Deploy modules translate these to --cap-drop / --cap-add flags.
{ lib, ... }:
{
  options.hardening.capabilities = lib.mkOption {
    type = lib.types.submodule {
      options = {
        drop = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "ALL" ];
          description = ''
            Linux capabilities to drop. Defaults to `["ALL"]`.
            Deploy modules translate to `--cap-drop`.
          '';
        };

        add = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Linux capabilities to add back after dropping.
            Deploy modules translate to `--cap-add`.
          '';
          example = [ "NET_BIND_SERVICE" ];
        };
      };
    };
    default = { };
    description = "Linux capability restrictions applied at runtime by deploy modules.";
  };
}
