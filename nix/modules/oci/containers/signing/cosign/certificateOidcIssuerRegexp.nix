# Container signing.cosign.certificateOidcIssuerRegexp option
{
  lib,
  config,
  ...
}:
let
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.signing.cosign.certificateOidcIssuerRegexp = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Regexp to match OIDC issuer when verifying keyless signatures.";
            default = cfg.oci.signing.cosign.certificateOidcIssuerRegexp;
            defaultText = lib.literalExpression "config.oci.signing.cosign.certificateOidcIssuerRegexp";
          };
        };
    };
}
