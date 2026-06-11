{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.oci.signing.cosign.key = mkOption {
    type = types.nullOr types.str;
    description = ''
      Path or KMS URI for the cosign signing key.
      Supports local files, environment variables, and KMS URIs:
        - Local file: `./cosign.key`
        - Environment variable: `env://COSIGN_PRIVATE_KEY`
        - AWS KMS: `awskms://[ENDPOINT]/[ID/ALIAS/ARN]`
        - GCP KMS: `gcpkms://projects/[PROJECT]/locations/[LOC]/keyRings/[RING]/cryptoKeys/[KEY]`
        - Azure Key Vault: `azurekms://[VAULT_NAME][VAULT_URI]/[KEY]`
        - HashCorp Vault: `hashivault://[KEY]`
      Only used when `keyless` is false.
    '';
    default = null;
  };
}
