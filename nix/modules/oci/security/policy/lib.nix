# OCI image config policy checking functions (Conftest)
import ../../../../lib/mkLibModule.nix (
  {
    pkgs,
    lib,
    ociLib,
    ...
  }:
  let
    thisFile = "nix/modules/oci/security/policy/lib.nix";
  in
  {
    mkScriptPolicyConftest = {
      type = lib.types.functionTo lib.types.package;
      description = "Generate Conftest OCI image config policy checking script";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId}.policy.conftest;
          namespaceFlags = lib.concatMapStringsSep " " (
            ns: "--namespace ${lib.escapeShellArg ns}"
          ) containerConfig.namespaces;
          effectivePolicyDir = ociLib.mkMergedPolicyDir {
            name = "conftest-${containerId}";
            baseDir = containerConfig.policyDir;
            extraDirs = containerConfig.extraPolicyDirs;
          };
          conftestBin = "${perSystemConfig.packages.conftest}/bin/conftest";
        in
        ociLib.mkArchiveScanScript {
          name = "policy-conftest-${containerId}";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          needsDockerConfig = false;
          scanCommand = ''
            # Extract OCI image config from the docker archive
            ${pkgs.gnutar}/bin/tar xf archive.tar -C "$WORK" manifest.json
            CONFIG_FILE=$(${pkgs.jq}/bin/jq -r '.[0].Config' "$WORK/manifest.json")
            ${pkgs.gnutar}/bin/tar xf archive.tar -C "$WORK" "$CONFIG_FILE"

            # Run conftest against the image config
            ${conftestBin} test "$WORK/$CONFIG_FILE" \
              --policy ${effectivePolicyDir} \
              ${namespaceFlags} \
              --no-color
          '';
          reportBlock = ociLib.mkReportBlock {
            reportCommand = ''
              ${conftestBin} test "$WORK/$CONFIG_FILE" \
                --policy ${effectivePolicyDir} \
                ${namespaceFlags} \
                --no-color \
                --output json \
                > "$CIMERA_REPORT_DIR/gl-policy-conftest-report.json" || true
            '';
            reportName = "gl-policy-conftest-report.json";
          };
        };
    };

    mkCheckPolicyConftest = {
      type = lib.types.functionTo lib.types.package;
      description = "Run Conftest OCI policy check directly on nix2container image.json (no archive)";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId}.policy.conftest;
          namespaceFlags = lib.concatMapStringsSep " " (
            ns: "--namespace ${lib.escapeShellArg ns}"
          ) containerConfig.namespaces;
          effectivePolicyDir = ociLib.mkMergedPolicyDir {
            name = "conftest-${containerId}";
            baseDir = containerConfig.policyDir;
            extraDirs = containerConfig.extraPolicyDirs;
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
      type = lib.types.functionTo lib.types.attrs;
      description = "Create flake app for Conftest OCI image config policy checking";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        {
          type = "app";
          program = "${
            ociLib.mkScriptPolicyConftest {
              inherit perSystemConfig containerId;
            }
          }/bin/policy-conftest-${containerId}";
        };
    };
  }
)
