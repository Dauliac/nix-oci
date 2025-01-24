localflake:
{
  config,
  lib,
  inputs,
  self,
  ...
}:
let
  localLib = localflake.config.lib;
  cfg = config;
  inherit (lib)
    mkOption
    types
    attrsets
    ;
in
{
  options = {
    perSystem = inputs.flake-parts.lib.mkPerSystemOption (
      {
        config,
        pkgs,
        system,
        ...
      }:
      {
        options.oci.internal = {
          CVETrivyOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "cve.trivy";
            };
          };
          CVETrivyApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
              default = attrsets.mapAttrs (
              ContainerId: oci:
              localLib.mkAppCVETrivy {
                inherit pkgs ContainerId;
                config = cfg.oci;
                perSystemConfig = config.oci;
                oci = oci.${ContainerId};
              }
            ) config.oci.internal.diveOCIs;
          };
          prefixedCVETrivyApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.prefixOutputs {
              prefix = "oci-cve-trivy-";
              set = config.oci.internal.CVETrivyApps;
            };
          };
          CVEGrypeOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "cve.grype";
            };
          };
          CVEGrypeApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              ContainerId: oci:
              localLib.mkAppCVEGrype {
                inherit pkgs ContainerId;
                config = cfg.oci;
                perSystemConfig = config.oci;
                oci = oci.${ContainerId};
              }
            ) config.oci.internal.CVEGrypeOCIs;
          };
          prefixedCVEGrypeApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.prefixOutputs {
              prefix = "oci-cve-grype-";
              set = config.oci.internal.CVEGrypeApps;
            };
          };
          SBOMSyftOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "sbom.syft";
            };
          };
          SBOMSyftOCIsApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              ContainerId: oci:
              localLib.mkAppSBOMSyft {
                inherit pkgs ContainerId;
                config = cfg.oci;
                perSystemConfig = config.oci;
                oci = oci.${ContainerId};
              }
            ) config.oci.internal.SBOMSyftOCIs;
          };
          prefixedSBOMSyftApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.prefixOutputs {
              prefix = "oci-sbom-syft-";
              set = config.oci.internal.SBOMSyftOCIsApps;
            };
          };
          credentialsLeakTrivyOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "credentialsLeak.trivy";
            };
          };
          credentialsLeakTrivyApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              ContainerId: oci:
              localLib.mkAppCredentialsLeakTrivy {
                inherit pkgs ContainerId;
                config = cfg.oci;
                perSystemConfig = config.oci;
                oci = oci.${ContainerId};
              }
            ) config.oci.internal.credentialsLeakTrivyOCIs;
          };
          prefixedCredentialsLeakTrivyApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.prefixOutputs {
              prefix = "oci-credentials-leak-";
              set = config.oci.internal.credentialsLeakTrivyApps;
            };
          };
          containerStructureTestOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "containerStructureTest";
            };
          };
          containerStructureTestOCIsApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              ContainerId: oci:
              localLib.mkAppContainerStructureTest {
                inherit pkgs ContainerId;
                config = cfg.oci;
                perSystemConfig = config.oci;
                oci = oci.${ContainerId};
              }
            ) config.oci.internal.containerStructureTestOCIs;
          };
          prefixedContainerStructureTestApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.prefixOutputs {
              prefix = "oci-container-structure-test-";
              set = config.oci.internal.containerStructureTestOCIsApps;
            };
          };
        };
      }
    );
  };
}
