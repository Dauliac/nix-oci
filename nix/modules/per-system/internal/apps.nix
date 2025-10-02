{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    types
    attrsets
    ;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        config,
        pkgs,
        ...
      }:
      {
        options.oci.internal = {
          CVETrivyOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "cve.trivy";
            };
          };
          CVETrivyApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: oci:
              cfg.oci.lib.mkAppCVETrivy {
                inherit pkgs containerId;
                config = cfg.oci;
                perSystemConfig = config.oci;
              }
            ) config.oci.internal.CVETrivyOCIs;
          };
          prefixedCVETrivyApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.prefixOutputs {
              prefix = "oci-cve-trivy-";
              set = config.oci.internal.CVETrivyApps;
            };
          };
          CVEGrypeOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "cve.grype";
            };
          };
          CVEGrypeApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: oci:
              cfg.oci.lib.mkAppCVEGrype {
                inherit pkgs containerId;
                perSystemConfig = config.oci;
              }
            ) config.oci.internal.CVEGrypeOCIs;
          };
          prefixedCVEGrypeApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.prefixOutputs {
              prefix = "oci-cve-grype-";
              set = config.oci.internal.CVEGrypeApps;
            };
          };
          SBOMSyftOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "sbom.syft";
            };
          };
          SBOMSyftOCIsApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: oci:
              cfg.oci.lib.mkAppSBOMSyft {
                inherit pkgs containerId;
                perSystemConfig = config.oci;
              }
            ) config.oci.internal.SBOMSyftOCIs;
          };
          prefixedSBOMSyftApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.prefixOutputs {
              prefix = "oci-sbom-syft-";
              set = config.oci.internal.SBOMSyftOCIsApps;
            };
          };
          credentialsLeakTrivyOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "credentialsLeak.trivy";
            };
          };
          credentialsLeakTrivyApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: oci:
              cfg.oci.lib.mkAppCredentialsLeakTrivy {
                inherit pkgs containerId;
                perSystemConfig = config.oci;
              }
            ) config.oci.internal.credentialsLeakTrivyOCIs;
          };
          prefixedCredentialsLeakTrivyApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.prefixOutputs {
              prefix = "oci-credentials-leak-";
              set = config.oci.internal.credentialsLeakTrivyApps;
            };
          };
          containerStructureTestOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "test.containerStructureTest";
            };
          };
          containerStructureTestOCIsApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: oci:
              cfg.oci.lib.mkAppContainerStructureTest {
                inherit pkgs containerId;
                perSystemConfig = config.oci;
              }
            ) config.oci.internal.containerStructureTestOCIs;
          };
          prefixedContainerStructureTestApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.prefixOutputs {
              prefix = "oci-container-structure-test-";
              set = config.oci.internal.containerStructureTestOCIsApps;
            };
          };
          dgossOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "test.dgoss";
            };
          };
          dgossOCIsApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: oci:
              cfg.oci.lib.mkAppDgoss {
                inherit pkgs containerId;
                perSystemConfig = config.oci;
              }
            ) config.oci.internal.dgossOCIs;
          };
          prefixedDgossApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.prefixOutputs {
              prefix = "oci-dgoss-";
              set = config.oci.internal.dgossOCIsApps;
            };
          };
        };
      }
    );
  };
}
