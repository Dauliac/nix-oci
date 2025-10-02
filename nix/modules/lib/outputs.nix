{ lib, ... }:
let
  inherit (lib)
    attrsets
    foldl'
    mkOption
    ;
in
{
  options.oci.lib = {
    prefixOutputs = mkOption {
      description = "A prefix to add to the output file.";
      default =
        {
          prefix,
          set,
        }:
        foldl' (
          acc: id:
          acc
          // {
            "${prefix}${id}" = set.${id};
          }
        ) { } (attrsets.attrNames set);
    };
    filterEnabledOutputsSet = mkOption {
      description = "A function to filter outputs.";
      default =
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
    };
  };
}
