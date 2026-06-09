# Generate full path for OCI manifest lock file
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCIPulledManifestLockPath = {
    type = lib.types.functionTo lib.types.path;
    description = "Generate the full path for an OCI manifest lock file";
    file = "nix/modules/oci/lib/ociMkOCIPulledManifestLockPath.nix";
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
          fromImageManifestRootPath = "./manifests";
          fromImage = {
            imageName = "library/alpine";
            imageTag = "3.18";
          };
        };
        expected = "./manifests/library-alpine-3.18-manifest-lock.json";
      };
    };
  };
}
