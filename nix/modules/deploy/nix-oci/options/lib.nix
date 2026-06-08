# services.nix-oci.lib — internal helpers, registered for both NixOS and home-manager.
#
# Types and descriptions inherited from `_lib/oci.nix` (single source of truth
# shared with flake-parts `nix-lib.lib.oci`).
{ ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.nix-oci;
      defs = import ../../../../modules/_lib/oci.nix { inherit lib; };
    in
    {
      options.services.nix-oci.lib = {
        mkImageRef = lib.mkOption {
          inherit (defs.mkImageRef) type description;
          internal = true;
          readOnly = true;
          default = defs.mkImageRef.fn;
        };

        mkLoadServiceName = lib.mkOption {
          inherit (defs.mkLoadServiceName) type description;
          internal = true;
          readOnly = true;
          default = defs.mkLoadServiceName.fn;
        };

        # Partially applied: takes `{ container }` instead of `{ backend, image }`.
        # Returns the nix2container passthru copy script (bundles skopeo-nix2container).
        copyScript = lib.mkOption {
          type = lib.types.unspecified;
          inherit (defs.copyScript) description;
          internal = true;
          readOnly = true;
          default =
            { container }:
            defs.copyScript.fn {
              backend = cfg.backend;
              image = container.image;
            };
        };
      };
    };
in
{
  flake.modules.nixos.nix-oci-lib = mod;
  flake.modules.homeManager.nix-oci-lib = mod;
}
