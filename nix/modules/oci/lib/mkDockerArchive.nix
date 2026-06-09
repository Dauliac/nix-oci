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
        file = "nix/modules/oci/lib/mkDockerArchive.nix";
        fn =
          {
            oci,
            skopeo,
          }:
          pkgs.runCommandLocal "docker-archive"
            {
              buildInputs = [
                skopeo
                pkgs.gnutar
              ];
              meta.description = "Docker archive from OCI image.";
            }
            ''
              set -e
              skopeo --tmpdir $TMP --insecure-policy copy nix:${oci} docker-archive:archive.tar

              # nix2container produces layer tars with absolute paths (/etc/passwd)
              # but the Docker archive spec expects relative paths (etc/passwd).
              # Tools like Dockle fail to inspect files when paths are absolute.
              # Rewrite paths in-place with --transform to preserve all file
              # attributes (uid/gid, permissions, xattrs, hardlinks, device nodes).
              mkdir -p repack
              cd repack
              tar xf ../archive.tar
              chmod -R u+w .

              for layer in *.tar *.tar.gz */layer.tar; do
                [ -f "$layer" ] || continue
                ${pkgs.python3}/bin/python3 ${./stripAbsolutePaths.py} "$layer"
              done

              tar cf $out --transform='s,^\./,,' .
            '';
      };
    };
}
