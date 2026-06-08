# Container signing.cosign.annotations option
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
          options.signing.cosign.annotations = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            description = "Key-value annotations to attach to the cosign signature for this container.";
            default = cfg.oci.signing.cosign.annotations;
            defaultText = lib.literalExpression "config.oci.signing.cosign.annotations";
          };
        };
    };
}
