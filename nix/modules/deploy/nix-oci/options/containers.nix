# oci.containers — registered for both NixOS and home-manager.
#
# Submodule options are auto-discovered from _containers/ via import-tree.
# nix2container and ociLib are threaded into the submodule via specialArgs.
{ import-tree, ... }:
let
  containerSubmodule = import-tree ./_containers;

  # Build ociLib from lib — these mirror the nix-lib functions in oci/lib/ports.nix
  # but are computed here so the NixOS submodule can use them without flake-parts config.
  mkOciLib =
    lib:
    let
      parseContainerPort =
        portSpec:
        let
          parts = lib.splitString ":" portSpec;
          raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
        in
        if lib.hasInfix "/" raw then raw else "${raw}/tcp";

      mkExposedPorts =
        ports:
        builtins.listToAttrs (map (p: lib.nameValuePair (parseContainerPort p) { }) ports);

      parseHostPort =
        portSpec:
        let
          raw = builtins.head (lib.splitString ":" portSpec);
          clean = builtins.head (lib.splitString "/" raw);
        in
        lib.toInt clean;
    in
    {
      inherit parseContainerPort mkExposedPorts parseHostPort;
    };

  mod =
    {
      lib,
      pkgs,
      nix2container,
      ...
    }:
    let
      ociLib = mkOciLib lib;
    in
    {
      options.oci.containers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submoduleWith {
            modules = [ containerSubmodule ];
            specialArgs = {
              inherit pkgs nix2container ociLib;
            };
          }
        );
        default = { };
        description = ''
          OCI containers to build, load, and optionally run.
          Each entry builds an image via nix2container and creates
          a systemd service to load it into the container runtime.
        '';
      };
    };
in
{
  flake.modules.nixos.nix-oci-containers = mod;
  flake.modules.homeManager.nix-oci-containers = mod;
}
