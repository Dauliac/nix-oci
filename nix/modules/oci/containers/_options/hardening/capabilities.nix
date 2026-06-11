# Shared: Linux capability restrictions.
#
# Capabilities partition root's monolithic privilege into distinct units.
# Deploy modules translate these to --cap-drop / --cap-add flags.
{
  lib,
  pkgs,
  ...
}:
let
  exampleAdd = [ "NET_BIND_SERVICE" ];
in
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
          example = exampleAdd;
        };
      };
    };
    default = { };
    description = "Linux capability restrictions applied at runtime by deploy modules.";
  };

  config._tests.hardening-capabilities = {
    level = "eval";
    default = {
      package = pkgs.hello;
      hardening.enable = true;
    };
    override = {
      package = pkgs.hello;
      hardening.enable = true;
      hardening.capabilities.add = exampleAdd;
    };
    assertions.imageConfig.Labels."io.github.dauliac.nix-oci.hardening.capabilities-add" =
      "NET_BIND_SERVICE";
  };
}
