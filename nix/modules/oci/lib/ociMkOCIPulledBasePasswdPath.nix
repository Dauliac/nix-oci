# Generate full path for pre-extracted base image /etc/passwd
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCIPulledBasePasswdPath = {
    type = lib.types.functionTo lib.types.path;
    description = "Generate the full path for a pre-extracted base image passwd file";
    file = "nix/modules/oci/lib/ociMkOCIPulledBasePasswdPath.nix";
    fn =
      {
        fromImageManifestRootPath,
        fromImage,
      }:
      let
        name = "/" + lib.strings.replaceStrings [ "/" ] [ "-" ] fromImage.imageName;
      in
      fromImageManifestRootPath + name + "-" + fromImage.imageTag + "-base-passwd";
    tests = {
      "generates correct base passwd path" = {
        args = {
          fromImageManifestRootPath = "./manifests";
          fromImage = {
            imageName = "library/alpine";
            imageTag = "3.18";
          };
        };
        expected = "./manifests/library-alpine-3.18-base-passwd";
      };
    };
  };
}
