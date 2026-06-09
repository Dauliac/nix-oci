# Derive container name from package or base image
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  nix-lib.lib.oci.mkOCIName = {
    type = lib.types.functionTo lib.types.str;
    description = "Derive container name from package mainProgram, pname, derivation name, or base image name";
    fn =
      {
        package,
        fromImage,
      }:
      if package != null then
        lib.strings.toLower (pure.resolveMainProgram package)
      else if fromImage.enabled then
        lib.strings.toLower fromImage.imageName
      else
        throw "Error: No valid source for name (name, package.meta.mainProgram, or fromImage.imageName) found.";
  };
}
