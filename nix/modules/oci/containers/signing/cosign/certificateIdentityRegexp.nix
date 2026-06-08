# Container signing.cosign.certificateIdentityRegexp option
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
          options.signing.cosign.certificateIdentityRegexp = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Regexp to match certificate identity when verifying keyless signatures.";
            default = cfg.oci.signing.cosign.certificateIdentityRegexp;
            defaultText = lib.literalExpression "config.oci.signing.cosign.certificateIdentityRegexp";
          };
        };
    };
}
