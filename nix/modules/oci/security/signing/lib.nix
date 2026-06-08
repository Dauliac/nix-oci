# OCI image signing functions (cosign)
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
in
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
    in
    {
      nix-lib.lib.oci = {
        mkScriptSignCosign = {
          type = types.functionTo types.package;
          description = ''
            Generate a cosign signing script for a pushed OCI image.

            The script takes the full image reference (e.g.
            `registry.example.com/myapp:v1.0.0`) as its first argument.
            It signs the image, optionally attaches annotations, and
            optionally verifies the signature.

            Supports both keyless (Sigstore OIDC) and key-based signing.
          '';
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              containerConfig = perSystemConfig.containers.${containerId};
              signingCfg = containerConfig.signing.cosign;
              appName = "sign-cosign-${containerId}";

              keyArgs =
                if signingCfg.keyless then
                  # Keyless: cosign uses OIDC automatically, set yes to
                  # skip interactive confirmation in CI
                  ""
                else
                  "--key ${signingCfg.key}";

              annotationArgs = lib.concatStringsSep " " (
                lib.mapAttrsToList (k: v: "-a ${lib.escapeShellArg "${k}=${v}"}") signingCfg.annotations
              );

              verifyKeyArgs =
                if signingCfg.keyless then
                  let
                    identityArg =
                      if signingCfg.certificateIdentityRegexp != null then
                        "--certificate-identity-regexp ${lib.escapeShellArg signingCfg.certificateIdentityRegexp}"
                      else
                        "";
                    issuerArg =
                      if signingCfg.certificateOidcIssuerRegexp != null then
                        "--certificate-oidc-issuer-regexp ${lib.escapeShellArg signingCfg.certificateOidcIssuerRegexp}"
                      else
                        "";
                  in
                  "${identityArg} ${issuerArg}"
                else
                  "--key ${signingCfg.key}";

              verifyBlock =
                if signingCfg.verify then
                  ''
                    echo "[${appName}] verifying signature on $REF"
                    if cosign verify ${verifyKeyArgs} "$REF" >&2; then
                      echo "[${appName}] signature verified successfully"
                    else
                      echo "[${appName}] WARNING: signature verification failed — this may be expected if certificate-identity/oidc-issuer regexps are not configured" >&2
                    fi
                  ''
                else
                  "";
            in
            pkgs.writeShellScriptBin appName ''
              set -o errexit
              set -o pipefail
              set -o nounset

              if [ $# -lt 1 ]; then
                echo "Usage: ${appName} <image-ref> [digest]" >&2
                echo "  image-ref: full OCI image reference (e.g. registry.example.com/myapp:v1.0.0)" >&2
                echo "  digest:    optional digest to sign (e.g. sha256:abc...). If provided, signs ref@digest." >&2
                exit 1
              fi

              REF="$1"
              DIGEST="''${2:-}"

              # If digest is provided, sign the specific digest to ensure
              # we sign the exact content that was pushed.
              if [ -n "$DIGEST" ]; then
                SIGN_REF="$REF@$DIGEST"
              else
                SIGN_REF="$REF"
              fi

              COSIGN="${perSystemConfig.packages.cosign}/bin/cosign"

              echo "[${appName}] signing $SIGN_REF"
              COSIGN_YES=1 $COSIGN sign ${keyArgs} ${annotationArgs} "$SIGN_REF" >&2

              echo "CIMERA_OCI_SIGNED ref=$SIGN_REF"

              ${verifyBlock}
            '';
        };

        mkAppSignCosign = {
          type = types.functionTo types.attrs;
          description = "Create flake app for cosign image signing";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptSignCosign {
                  inherit perSystemConfig containerId;
                }
              }/bin/sign-cosign-${containerId}";
            };
        };
      };
    };
}
