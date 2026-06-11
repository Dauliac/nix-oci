{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.oci.signing.cosign.certificateOidcIssuerRegexp = mkOption {
    type = types.nullOr types.str;
    description = ''
      Regular expression to match the OIDC issuer when verifying
      keyless signatures. Required for keyless verification.
      Example: `"https://token.actions.githubusercontent.com"`.
    '';
    default = null;
  };
}
