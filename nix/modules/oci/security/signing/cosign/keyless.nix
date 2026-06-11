{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.oci.signing.cosign.keyless = mkOption {
    type = types.bool;
    description = ''
      Use keyless (OIDC) signing via Sigstore Fulcio.
      When true, cosign authenticates via an OIDC provider
      (GitHub Actions, Google, Microsoft) and issues ephemeral
      certificates. No key management required.
      When false, `key` must be set.
    '';
    default = true;
  };
}
