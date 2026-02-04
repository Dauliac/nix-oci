# Generate relative path for a specific manifest lock file
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCIPulledManifestLockRelativePath = {
    type = lib.types.functionTo lib.types.str;
    description = "Generate relative path for a specific manifest lock file";
    fn =
      {
        self,
        manifestLockPath,
      }:
      "./" + lib.strings.replaceStrings [ ((toString self) + "/") ] [ "" ] (toString manifestLockPath);
    tests = {
      "generates relative manifest path" = {
        args = {
          self = /home/user/project;
          manifestLockPath = /home/user/project/oci/manifests/alpine-3.18-manifest-lock.json;
        };
        expected = "./oci/manifests/alpine-3.18-manifest-lock.json";
      };
    };
  };
}
