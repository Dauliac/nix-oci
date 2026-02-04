# Get relative root path for manifest locks from flake self
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCIPulledManifestLockRelativeRootPath = {
    type = lib.types.functionTo lib.types.str;
    description = "Get relative root path for manifest locks from flake self";
    fn =
      {
        self,
        fromImageManifestRootPath,
      }:
      "./"
      + (lib.strings.replaceStrings [ ((toString self) + "/") ] [ "" ] (
        toString fromImageManifestRootPath
      ))
      + "/";
    tests = {
      "generates relative root path" = {
        args = {
          self = /home/user/project;
          fromImageManifestRootPath = /home/user/project/oci/manifests;
        };
        expected = "./oci/manifests/";
      };
    };
  };
}
