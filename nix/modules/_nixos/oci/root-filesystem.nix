# Root filesystem: package/deps/configFiles options, home dir lib, and output
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
in
{
  options.oci.container = {
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Main package for the container.";
    };
    configFiles = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional config file derivations for the root filesystem.";
    };
    dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to include in the root filesystem.";
    };
  };

  options.oci.lib.mkHomeDirDrv = lib.mkOption {
    type = lib.types.unspecified;
    internal = true;
    readOnly = true;
    description = "Home directory derivation, with home-manager files if available.";
    default =
      let
        homeDir = config.oci.lib.homeDir;
        hmActivation =
          let
            hmUsers = config.home-manager.users or { };
            hmUser = hmUsers.${cfg.user} or null;
          in
          if hmUser != null then hmUser.home.activationPackage or null else null;
      in
      if hmActivation != null then
        pkgs.runCommand "home-dir-hm" { } ''
          mkdir -p $out${homeDir}
          if [ -d "${hmActivation}/home-files" ]; then
            cp -rT ${hmActivation}/home-files $out${homeDir}
          fi
        ''
      else
        pkgs.runCommand "home-dir" { } "mkdir -p $out${homeDir}";
  };

  options.oci.container._output.rootFilesystem = lib.mkOption {
    type = lib.types.package;
    internal = true;
    readOnly = true;
    description = "Complete root filesystem (shadow + etc + deps + configFiles + home).";
    default =
      let
        package' = if cfg.package != null then [ cfg.package ] else [ ];
        systemPackages = config.environment.systemPackages or [ ];
      in
      pkgs.buildEnv {
        name = "root";
        paths =
          package'
          ++ systemPackages
          ++ cfg._output.shadowFiles
          ++ cfg._output.etcFiles
          ++ cfg.dependencies
          ++ cfg.configFiles
          ++ (cfg._output.hardening.configFiles or [ ])
          ++ (cfg._output.performance.extraDeps or [ ])
          ++ [
            config.oci.lib.mkHomeDirDrv
            (pkgs.runCommand "fhs-tmp" { } "mkdir -p $out/tmp $out/var/tmp")
          ];
        pathsToLink = [
          "/bin"
          "/lib"
          "/etc"
          "/home"
          "/root"
          "/tmp"
          "/var"
        ];
      };
  };
}
