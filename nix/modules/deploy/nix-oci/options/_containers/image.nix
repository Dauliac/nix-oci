# Per-container: computed OCI image built from package + dependencies.
#
# Uses nix2container (injected via specialArgs) to build the image.
# Shadow files for non-root containers. ExposedPorts from ports option.
# Environment variables baked into the image manifest.
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
  shadowSetup =
    if config.isRoot then
      [
        (pkgs.writeTextDir "etc/passwd" "root:x:0:0::/root:${pkgs.runtimeShell}\n")
        (pkgs.writeTextDir "etc/shadow" "root:!x:::::::\n")
        (pkgs.writeTextDir "etc/group" "root:x:0:\n")
      ]
    else
      [
        (pkgs.writeTextDir "etc/passwd" ''
          root:x:0:0::/root:${pkgs.runtimeShell}
          ${config.user}:x:4000:4000::/home/${config.user}:${pkgs.runtimeShell}
        '')
        (pkgs.writeTextDir "etc/shadow" ''
          root:!x:::::::
          ${config.user}:!:::::::
        '')
        (pkgs.writeTextDir "etc/group" ''
          root:x:0:
          ${config.user}:x:4000:
        '')
        (pkgs.runCommand "home-${config.user}" { } ''
          mkdir -p $out/home/${config.user}
        '')
      ];

  root = pkgs.buildEnv {
    name = "oci-root-${name}";
    paths = [ config.package ] ++ config.dependencies ++ shadowSetup;
    pathsToLink = [
      "/bin"
      "/lib"
      "/etc"
      "/home"
    ];
    ignoreCollisions = true;
  };

  entrypoint =
    if config.entrypoint != [ ] then
      config.entrypoint
    else
      let
        mainProgram = config.package.meta.mainProgram or config.package.pname or name;
      in
      [ "${config.package}/bin/${mainProgram}" ];

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
