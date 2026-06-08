{
  config,
  lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    mkEnableOption
    types
    ;
in
{
  options = {
    oci = {
      signing = mkOption {
        default = { };
        description = "Configuration for OCI image signing using cosign / Sigstore.";
        type = types.submodule {
          options = {
            cosign = mkOption {
              default = { };
              description = "Configuration for image signing with cosign.";
              type = types.submodule {
                options = {
                  enabled = mkEnableOption "OCI image signing with cosign";
                  keyless = mkOption {
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
                  key = mkOption {
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
                  annotations = mkOption {
                    type = types.attrsOf types.str;
                    description = ''
                      Key-value annotations to attach to every cosign signature.
                      These appear in `cosign verify` output and can be used
                      for policy enforcement (e.g. with Kyverno or OPA).
                    '';
                    default = { };
                    example = {
                      "repo" = "https://github.com/example/repo";
                      "build-system" = "nix";
                    };
                  };
                  verify = mkOption {
                    type = types.bool;
                    description = "Whether to verify the signature immediately after signing.";
                    default = true;
                  };
                  certificateIdentityRegexp = mkOption {
                    type = types.nullOr types.str;
                    description = ''
                      Regular expression to match the certificate identity when
                      verifying keyless signatures. Required for keyless verification.
                      Example: `"https://github.com/myorg/.*"` or an email pattern.
                    '';
                    default = null;
                  };
                  certificateOidcIssuerRegexp = mkOption {
                    type = types.nullOr types.str;
                    description = ''
                      Regular expression to match the OIDC issuer when verifying
                      keyless signatures. Required for keyless verification.
                      Example: `"https://token.actions.githubusercontent.com"`.
                    '';
                    default = null;
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
