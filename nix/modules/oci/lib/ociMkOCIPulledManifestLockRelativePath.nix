# Generate relative path for a specific manifest lock file
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCIPulledManifestLockRelativePath = {
    type = lib.types.functionTo lib.types.str;
    description = "Generate relative path for a specific manifest lock file";
    file = "nix/modules/oci/lib/ociMkOCIPulledManifestLockRelativePath.nix";
    fn =
      {
        self,
        manifestLockPath,
      }:
      "./" + lib.strings.replaceStrings [ ((toString self) + "/") ] [ "" ] (toString manifestLockPath);
    tests = {
      "generates relative manifest path" = {
        args = {
          self = "/project";
          manifestLockPath = "/project/oci/manifests/alpine-3.18-manifest-lock.json";
        };
        expected = "./oci/manifests/alpine-3.18-manifest-lock.json";
      };
    };
  };
}
