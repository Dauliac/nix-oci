# Derive container tag from package version or base image tag
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCITag = {
    type = lib.types.functionTo lib.types.str;
    description = "Derive container tag from package version or base image tag";
    fn =
      {
        package,
        fromImage,
      }:
      if package != null && package.version != null then
        package.version
      else if fromImage.enabled && fromImage.imageTag != null then
        fromImage.imageTag
      else
        throw "Empty tag given and impossible to infer it from package or fromImage";
    tests = {
      "derives tag from package version" = {
        args = {
          package = {
            version = "1.2.3";
          };
          fromImage = {
            enabled = false;
          };
        };
        expected = "1.2.3";
      };
      "derives tag from fromImage when package has no version" = {
        args = {
          package = null;
          fromImage = {
            enabled = true;
            imageTag = "latest";
          };
        };
        expected = "latest";
      };
    };
  };
}
