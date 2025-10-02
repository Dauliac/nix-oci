{ inputs, ... }:
{
  imports = inputs.nixpkgs.lib.fileset.toList (
    inputs.nixpkgs.lib.fileset.fileFilter (file: file.hasExt "nix") ../examples
  );
  config.oci.fromImageManifestRootPath = ../examples + "/";
}
