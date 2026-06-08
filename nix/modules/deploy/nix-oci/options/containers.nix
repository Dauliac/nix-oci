# services.nix-oci.containers — registered for both NixOS and home-manager.
#
# Submodule options are inlined (no import-tree dependency).
{ ... }:
let
  mod =
    { lib, ... }:
    {
      options.services.nix-oci.containers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            imports = [
              ./_containers/image.nix
              ./_containers/image-ref.nix
              ./_containers/auto-start.nix
            ];
          }
        );
        default = { };
        description = ''
          Containers to load from the Nix store into the container runtime.
          Each entry creates a `nix-oci-load-<name>.service` oneshot unit.
        '';
      };
    };
in
{
  flake.modules.nixos.nix-oci-containers = mod;
  flake.modules.homeManager.nix-oci-containers = mod;
}
