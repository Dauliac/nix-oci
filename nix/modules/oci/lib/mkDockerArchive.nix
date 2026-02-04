# OCI mkDockerArchive - Transform nix2container build into docker archive via skopeo
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkDockerArchive = {
        type = lib.types.functionTo lib.types.package;
        description = "Transform nix2container build into docker archive via skopeo";
        fn =
          {
            oci,
            skopeo,
          }:
          pkgs.runCommandLocal "docker-archive"
            {
              buildInputs = [ skopeo ];
              meta.description = "Docker archive from OCI image.";
            }
            ''
              set -e
              skopeo --tmpdir $TMP --insecure-policy copy nix:${oci} docker-archive:archive.tar
              mv archive.tar $out
            '';
      };
    };
}
