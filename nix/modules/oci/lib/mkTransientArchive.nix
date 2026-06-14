# Shell snippet to create a transient docker archive from a nix2container image.
#
# Returns a shell string (NOT a derivation). The archive is created in the
# current directory as archive.tar and layers are rewritten to relative paths.
# The archive is never stored in the nix store — it lives in the build sandbox
# and is discarded after the derivation completes.
#
# Usage in a derivation:
#   ''
#     ${ociLib.mkTransientArchive { inherit oci skopeo; }}
#     # archive.tar now exists in $PWD
#     conftest test config.json ...
#     touch $out
#   ''
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkTransientArchive = {
        type = lib.types.functionTo lib.types.str;
        description = "Shell snippet to create a transient docker archive (never stored in nix store).";
        file = "nix/modules/oci/lib/mkTransientArchive.nix";
        fn =
          {
            oci,
            skopeo,
          }:
          ''
            # Create transient docker archive (discarded after build)
            ${skopeo}/bin/skopeo --tmpdir $TMPDIR --insecure-policy copy nix:${oci} docker-archive:archive.tar

            # Fix absolute paths in layers (nix2container produces /etc/passwd,
            # Docker archive spec expects etc/passwd)
            mkdir -p _repack
            cd _repack
            ${pkgs.gnutar}/bin/tar xf ../archive.tar
            chmod -R u+w .
            for layer in *.tar *.tar.gz */layer.tar; do
              [ -f "$layer" ] || continue
              ${pkgs.python3}/bin/python3 ${./stripAbsolutePaths.py} "$layer"
            done
            ${pkgs.gnutar}/bin/tar cf ../archive.tar --transform='s,^\./,,' .
            cd ..
            rm -rf _repack
          '';
      };
    };
}
