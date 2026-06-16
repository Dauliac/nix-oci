# OCI image config policy checking functions (Conftest)
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
        mkScriptPolicyConftest = {
          type = types.functionTo types.package;
          description = "Generate Conftest OCI image config policy checking script";
          file = "nix/modules/oci/security/policy/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.policy.conftest;
              mkTransientArchive = ociLib.mkTransientArchive {
                inherit oci;
                skopeo = perSystemConfig.packages.skopeo;
              };
              namespaceFlags = lib.concatMapStringsSep " " (
                ns: "--namespace ${lib.escapeShellArg ns}"
              ) containerConfig.namespaces;
              effectivePolicyDir =
                if containerConfig.extraPolicyDirs == [ ] then
                  containerConfig.policyDir
                else
                  pkgs.symlinkJoin {
                    name = "merged-conftest-policies-${containerId}";
                    paths = [ containerConfig.policyDir ] ++ containerConfig.extraPolicyDirs;
                  };
            in
            pkgs.writeShellScriptBin "policy-conftest-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset

              CONFTEST="${perSystemConfig.packages.conftest}/bin/conftest"
              WORK="$(mktemp -d)"
              trap 'rm -rf "$WORK"' EXIT
              cd "$WORK"

              # Create transient archive
              ${mkTransientArchive}

              # Extract OCI image config from the docker archive
              ${pkgs.gnutar}/bin/tar xf archive.tar -C "$WORK" manifest.json
              CONFIG_FILE=$(${pkgs.jq}/bin/jq -r '.[0].Config' "$WORK/manifest.json")
              ${pkgs.gnutar}/bin/tar xf archive.tar -C "$WORK" "$CONFIG_FILE"

              # Run conftest against the image config
              $CONFTEST test "$WORK/$CONFIG_FILE" \
                --policy ${effectivePolicyDir} \
                ${namespaceFlags} \
                --no-color

              # Write JSON report when CIMERA_REPORT_DIR is set
              if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                mkdir -p "$CIMERA_REPORT_DIR"
                $CONFTEST test "$WORK/$CONFIG_FILE" \
                  --policy ${effectivePolicyDir} \
                  ${namespaceFlags} \
                  --no-color \
                  --output json \
                  > "$CIMERA_REPORT_DIR/gl-policy-conftest-report.json" || true
              fi
            '';
        };

        mkCheckPolicyConftest = {
          type = types.functionTo types.package;
          description = "Run Conftest OCI policy check directly on nix2container image.json (no archive)";
          file = "nix/modules/oci/security/policy/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.policy.conftest;
              namespaceFlags = lib.concatMapStringsSep " " (
                ns: "--namespace ${lib.escapeShellArg ns}"
              ) containerConfig.namespaces;
              effectivePolicyDir =
                if containerConfig.extraPolicyDirs == [ ] then
                  containerConfig.policyDir
                else
                  pkgs.symlinkJoin {
                    name = "merged-conftest-policies-${containerId}";
                    paths = [ containerConfig.policyDir ] ++ containerConfig.extraPolicyDirs;
                  };
            in
            pkgs.runCommandLocal "policy-conftest-${containerId}"
              {
                nativeBuildInputs = [
                  perSystemConfig.packages.conftest
                ];
                meta.description = "Run Conftest OCI policy check on ${containerId}.";
              }
              ''
                ${perSystemConfig.packages.conftest}/bin/conftest test ${oci} \
                  --policy ${effectivePolicyDir} \
                  ${namespaceFlags} \
                  --no-color
                touch $out
              '';
        };

        mkAppPolicyConftest = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Conftest OCI image config policy checking";
          file = "nix/modules/oci/security/policy/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptPolicyConftest {
                  inherit perSystemConfig containerId globalConfig;
                }
              }/bin/policy-conftest-${containerId}";
            };
        };
      };
    };
}
