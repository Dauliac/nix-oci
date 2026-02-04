# Generate full path for OCI manifest lock file
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCIPulledManifestLockPath = {
    type = lib.types.functionTo lib.types.path;
    description = "Generate the full path for an OCI manifest lock file";
    fn =
      {
        fromImageManifestRootPath,
        fromImage,
      }:
      let
        name = "/" + lib.strings.replaceStrings [ "/" ] [ "-" ] fromImage.imageName;
      in
      fromImageManifestRootPath + name + "-" + fromImage.imageTag + "-manifest-lock.json";
    tests = {
      "generates correct manifest lock path" = {
        args = {
          fromImageManifestRootPath = /tmp/manifests;
          fromImage = {
            imageName = "library/alpine";
            imageTag = "3.18";
          };
        };
        expected = /tmp/manifests/library-alpine-3.18-manifest-lock.json;
      };
    };
  };
}
