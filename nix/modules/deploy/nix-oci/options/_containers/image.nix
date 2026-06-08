# Per-container: computed OCI image built from shared options via nix2container.
#
# Uses ociLib.mkRoot for the root filesystem and ociLib.mkImageLayers for
# deduplicated layering when optimizeLayers is enabled.
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
  # Shadow setup + package + deps + configFiles as a single buildEnv.
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

  # Separate shadow setup (without deps/package) for optimized layering.
  # When optimized, deps go into their own layer via mkImageLayers.
  shadowOnly = ociLib.mkShadowSetup {
    inherit (config) isRoot user;
    inherit pkgs;
    runtimeShell = pkgs.runtimeShell;
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

  ociConfig = {
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

  optimized = config.optimizeLayers;
  layerStrategy = config.layerStrategy or "fine-grained";

  # When optimized, split into layers: shadow+configFiles as root,
  # dependencies as a separate layer, package as the top layer.
  # All chained via foldImageLayers for deduplication.
  rootPaths =
    shadowOnly ++ config.configFiles ++ lib.optional (config.package != null) config.package;

  layers = ociLib.mkImageLayers {
    inherit pkgs nix2container layerStrategy;
    inherit (config) dependencies;
    inherit rootPaths;
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
        config = ociConfig;
      }
      // (
        if optimized then
          {
            inherit layers;
          }
          // lib.optionalAttrs (layerStrategy == "fine-grained") {
            maxLayers = 40;
          }
        else
          {
            copyToRoot = [ root ];
          }
      )
    );
  };
}
