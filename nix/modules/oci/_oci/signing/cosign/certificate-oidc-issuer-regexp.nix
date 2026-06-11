{ lib, ... }:
{
  options.signing.cosign.certificateOidcIssuerRegexp = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    description = ''
      Regular expression to match the OIDC issuer when verifying
      keyless signatures. Required for keyless verification.
      Example: `"https://token.actions.githubusercontent.com"`.
    '';
    default = null;
  };
}
