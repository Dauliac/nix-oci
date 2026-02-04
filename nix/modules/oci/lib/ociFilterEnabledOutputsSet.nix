# Filter config attrset to only include enabled items
{ lib, ... }:
let
  inherit (lib) attrsets;
in
{
  nix-lib.lib.oci.filterEnabledOutputsSet = {
    type = lib.types.functionTo lib.types.attrs;
    description = "Filter a config attrset to only include items where subConfig.enabled is true";
    fn =
      {
        config,
        subConfig,
      }:
      let
        subConfigPath = lib.splitString "." subConfig;
      in
      attrsets.filterAttrs (
        id: value:
        let
          subConfigValue = lib.attrByPath subConfigPath null value;
        in
        subConfigValue != null && subConfigValue.enabled == true
      ) config;
    tests = {
      "filters to only enabled items" = {
        args = {
          config = {
            container1 = {
              cve.trivy.enabled = true;
            };
            container2 = {
              cve.trivy.enabled = false;
            };
            container3 = {
              cve.trivy.enabled = true;
            };
          };
          subConfig = "cve.trivy";
        };
        expected = {
          container1 = {
            cve.trivy.enabled = true;
          };
          container3 = {
            cve.trivy.enabled = true;
          };
        };
      };
    };
  };
}
