# OCI packages - oras
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.oras = lib.mkOption rec {
        type = lib.types.package;
        description = ''
          The package to use for oras (OCI Registry As Storage).

          Used by the referrer-attach substrate to publish signed blobs
          as OCI referrers of a pushed image via the distribution-spec
          1.1 Referrers API (with tag-schema fallback for pre-1.1
          registries).
        '';
        default = pkgs.oras;
        defaultText = lib.literalExpression "pkgs.oras";
        example = defaultText;
      };
    }
  );
}
