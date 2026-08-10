# Per-arch performance: defaults from archMap + container sugar.
#
# This perArchitecture contribution:
#   1. Inherits container-level performance.hwcaps as defaults (sugar)
#   2. Auto-disables hwcaps on unsupported architectures
{ lib, ... }:
{
  config.perSystem =
    { config, ... }:
    let
      ociLib = config.lib.oci or { };
    in
    {
      oci.perArchitecture = [
        (
          {
            name, # target system string
            config,
            containerConfig,
            ...
          }:
          let
            microarch =
              (ociLib.archMap).${name}.microarch or {
                hwcapsSupported = false;
                hwcapsLevels = [ ];
                marchValues = [ ];
                defaultHwcaps = [ ];
              };
            containerPerf = containerConfig.performance or { };
          in
          {
            config = {
              # Inherit container-level hwcaps, auto-disable on unsupported arches.
              performance.hwcaps = {
                enable = lib.mkDefault (microarch.hwcapsSupported && (containerPerf.hwcaps.enable or false));
                levels = lib.mkDefault (
                  if microarch.hwcapsSupported then
                    let
                      containerLevels = containerPerf.hwcaps.levels or [ ];
                    in
                    if containerLevels != [ ] then containerLevels else microarch.defaultHwcaps
                  else
                    [ ]
                );
                libraries = lib.mkDefault (containerPerf.hwcaps.libraries or [ ]);
              };
            };

            # hwcaps levels are validated by the option type (enum).
          }
        )
      ];
    };
}
