# Register mkGatedImage in flake-parts nix-lib.
#
# Provides `config.lib.oci.mkGatedImage`.
# Pure library: nix/lib/gated-image.nix
{ ... }:
let
  gatedImageLib = import ../../../lib/gated-image.nix;
in
{
  config.perSystem =
    { lib, ... }:
    let
      gated = gatedImageLib { inherit lib; };
    in
    {
      nix-lib.lib.oci.mkGatedImage = {
        type = lib.types.functionTo lib.types.attrs;
        description = ''
          Create a gated OCI image with embedded check dependencies.

          Returns the raw image attrset with an added `.gate` derivation.
          Building `.gate` forces all checks to pass. The image itself
          (outPath, copyToRegistry, etc.) is unchanged.

          Arguments (attrset): { pkgs, rawImage, checks, name }
          - pkgs: nixpkgs package set
          - rawImage: nix2container image derivation
          - checks: list of check derivations (dive, dockle, conftest, etc.)
          - name: container name for derivation naming
        '';
        file = "nix/lib/gated-image.nix";
        fn = gated.mkGatedImage;
      };
    };
}
