{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.oci.signing.cosign.certificateIdentityRegexp = mkOption {
    type = types.nullOr types.str;
    description = ''
      Regular expression to match the certificate identity when
      verifying keyless signatures. Required for keyless verification.
      Example: `"https://github.com/myorg/.*"` or an email pattern.
    '';
    default = null;
  };
}
