# Derive container name from package or base image
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCIName = {
    type = lib.types.functionTo lib.types.str;
    description = "Derive container name from package mainProgram or base image name";
    fn =
      {
        package,
        fromImage,
      }:
      if package != null then
        lib.strings.toLower package.meta.mainProgram
      else if fromImage.enabled then
        lib.strings.toLower fromImage.imageName
      else
        throw "Error: No valid source for name (name, package.meta.mainProgram, or fromImage.imageName) found.";
    tests = {
      "derives name from package mainProgram" = {
        args = {
          package = {
            meta.mainProgram = "MyApp";
          };
          fromImage = {
            enabled = false;
          };
        };
        expected = "myapp";
      };
      "derives name from fromImage when package is null" = {
        args = {
          package = null;
          fromImage = {
            enabled = true;
            imageName = "library/Alpine";
          };
        };
        expected = "library/alpine";
      };
    };
  };
}
