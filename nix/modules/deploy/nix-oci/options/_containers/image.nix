# Per-container: computed OCI image built from shared options via nix2container.
#
# Uses ociLib.mkRoot for shadow setup and root filesystem (shared build logic).
# ExposedPorts from ports, Env from environment, Labels from labels.
{
  name,
  config,
  lib,
  pkgs,
  nix2container,
  ociLib,
  ...
}:
let
  root = ociLib.mkRoot {
    inherit name pkgs;
    inherit (config)
      package
      dependencies
      configFiles
      isRoot
      user
      ;
  };

  entrypoint =
    if config.entrypoint != [ ] then
      config.entrypoint
    else if config.package != null then
      let
        mainProgram = config.package.meta.mainProgram or config.package.pname or name;
      in
      [ "${config.package}/bin/${mainProgram}" ]
    else
      [ ];

  ociConfig =
    {
      entrypoint = entrypoint;
      User = if config.isRoot then "root" else config.user;
    }
    // lib.optionalAttrs (config.ports != [ ]) {
      ExposedPorts = ociLib.mkExposedPorts config.ports;
    }
    // lib.optionalAttrs (config.environment != { }) {
      Env = lib.mapAttrsToList (k: v: "${k}=${v}") config.environment;
    }
    // lib.optionalAttrs (config.labels != { }) {
      Labels = config.labels;
    };
in
{
  options.image = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "Built OCI image (computed from package + dependencies via nix2container).";
    default = nix2container.buildImage (
      {
        name = config.name;
        tag = config.tag;
        copyToRoot = [ root ];
        config = ociConfig;
      }
      // lib.optionalAttrs config.optimizeLayers { maxLayers = 40; }
    );
  };
}
