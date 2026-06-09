# Per-arch performance: validation + defaults from archMap + container sugar.
#
# This perArchitecture contribution:
#   1. Inherits container-level performance.{march,hwcaps} as defaults (sugar)
#   2. Auto-disables hwcaps on unsupported architectures
#   3. Validates march/hwcaps.levels against archMap.microarch
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
              # Inherit container-level march (sugar), only if valid for this arch.
              # Container-level march is validated separately (per-container assertions).
              performance.march = lib.mkDefault (
                let
                  cm = containerPerf.march or null;
                in
                if cm != null && builtins.elem cm microarch.marchValues then cm else null
              );

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

            # Validation via option type checks -- the perArch submodule
            # does not have NixOS-level `assertions`. Instead, invalid
            # march values are caught by the image builder at build time
            # (the stdenvAdapters.withCFlags call will fail with an
            # unrecognized -march value).
          }
        )
      ];
    };
}
