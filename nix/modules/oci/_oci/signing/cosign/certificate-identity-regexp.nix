{ lib, ... }:
{
  options.signing.cosign.certificateIdentityRegexp = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    description = ''
      Regular expression to match the certificate identity when
      verifying keyless signatures. Required for keyless verification.
      Example: `"https://github.com/myorg/.*"` or an email pattern.
    '';
    default = null;
  };
}
