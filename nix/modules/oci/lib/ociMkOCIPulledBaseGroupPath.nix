# Generate full path for pre-extracted base image /etc/group
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCIPulledBaseGroupPath = {
    type = lib.types.functionTo lib.types.path;
    description = "Generate the full path for a pre-extracted base image group file";
    file = "nix/modules/oci/lib/ociMkOCIPulledBaseGroupPath.nix";
    fn =
      {
        fromImageManifestRootPath,
        fromImage,
      }:
      let
        name = "/" + lib.strings.replaceStrings [ "/" ] [ "-" ] fromImage.imageName;
      in
      fromImageManifestRootPath + name + "-" + fromImage.imageTag + "-base-group";
    tests = {
      "generates correct base group path" = {
        args = {
          fromImageManifestRootPath = "./manifests";
          fromImage = {
            imageName = "library/alpine";
            imageTag = "3.18";
          };
        };
        expected = "./manifests/library-alpine-3.18-base-group";
      };
    };
  };
}
