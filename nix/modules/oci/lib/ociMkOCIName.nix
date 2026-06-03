# Derive container name from package or base image
{ lib, ... }:
let
  # Resolve the program name from a package, with fallback chain:
  # meta.mainProgram -> pname -> parsed derivation name
  resolveMainProgram =
    package:
    if package.meta.mainProgram or null != null then
      package.meta.mainProgram
    else if package.pname or null != null then
      package.pname
    else
      (builtins.parseDrvName (package.name or "unknown")).name;
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
        lib.strings.toLower (resolveMainProgram package)
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
      "derives name from pname when mainProgram is missing" = {
        args = {
          package = {
            pname = "my-script";
            name = "my-script";
            meta = { };
          };
          fromImage = {
            enabled = false;
          };
        };
        expected = "my-script";
      };
      "derives name from derivation name as last resort" = {
        args = {
          package = {
            name = "my-script";
            meta = { };
          };
          fromImage = {
            enabled = false;
          };
        };
        expected = "my-script";
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
