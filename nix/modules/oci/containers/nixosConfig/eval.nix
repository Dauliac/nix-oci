# Container nixosConfig.eval - unified NixOS evaluation
#
# Imports nix/nixos/oci-container.nix, passes container options, merges
# user's nixosConfig.modules and homeConfig.modules.
#
# Cycle-safe reads: isRoot, _containerName, mainService, package (when
# mainService is null), dependencies, configFiles.
# NEVER reads: user, name, entrypoint (they depend on eval).
# package is safe to read ONLY when mainService is null, because
# integration.nix only sets package from eval when mainService is set.
{
  lib,
  import-tree,
  ...
}:
let
  inherit (lib) mkOption types;
  ociNixOSModule = import-tree ../../../_nixos/oci;
in
{
  config.perSystem =
    { pkgs, ... }:
    {
      oci.perContainer =
        { config, ... }:
        let
          nixosCfg = config.nixosConfig;
          homeCfg = config.homeConfig;

          containerIsRoot = config.isRoot;
          mainService = nixosCfg.mainService or null;

          # Resolve package name: meta.mainProgram -> pname -> parsed drv name
          packageName = pkg:
            if pkg.meta.mainProgram or null != null then pkg.meta.mainProgram
            else if pkg.pname or null != null then pkg.pname
            else (builtins.parseDrvName (pkg.name or "unknown")).name;

          # Derive container user with this priority:
          # 1. mainService set → use service name (e.g. "nginx")
          # 2. package set, no mainService → use package name (e.g. "kubectl")
          #    Safe: integration.nix only sets package from eval when mainService is set
          # 3. fallback → _containerName (attrset key)
          # Truncate to 31 chars — NixOS rejects user/group names longer than that.
          containerUser =
            if containerIsRoot then "root"
            else builtins.substring 0 31 (
              if mainService != null then mainService
              else if config.package != null then lib.strings.toLower (packageName config.package)
              else config._containerName
            );

          homeManagerModules =
            if homeCfg.enable && homeCfg.homeManagerFlake != null then
              let
                hmFlake = homeCfg.homeManagerFlake;
                hmNixosModule = hmFlake.nixosModules.home-manager or hmFlake.nixosModule or null;
              in
              if hmNixosModule != null then
                [
                  hmNixosModule
                  (
                    { lib, ... }:
                    {
                      home-manager.useGlobalPkgs = lib.mkDefault true;
                      home-manager.useUserPackages = lib.mkDefault true;
                      home-manager.users.${containerUser} =
                        { lib, ... }:
                        {
                          imports = homeCfg.modules;
                          home.stateVersion = lib.mkDefault "25.05";
                        };
                    }
                  )
                ]
              else
                builtins.throw "homeConfig.homeManagerFlake does not provide nixosModules.home-manager"
            else
              [ ];

          userModules = if nixosCfg.enable then nixosCfg.modules else [ ];

          evalResult =
            (import "${pkgs.path}/nixos/lib/eval-config.nix" {
              inherit (pkgs) system;
              modules = [
                ociNixOSModule
                # Pass cycle-safe container options into the NixOS module
                (
                  { lib, ... }:
                  {
                    nixpkgs.hostPlatform = lib.mkDefault pkgs.system;
                    oci.container = {
                      user = containerUser;
                      isRoot = containerIsRoot;
                      mainService = nixosCfg.mainService or null;
                      # dependencies and configFiles don't depend on eval — safe to pass
                      dependencies = config.dependencies;
                      configFiles = config.configFiles;
                    };
                  }
                )
              ]
              ++ userModules
              ++ homeManagerModules;
            }).config;
        in
        {
          options.nixosConfig.eval = mkOption {
            type = types.nullOr types.unspecified;
            internal = true;
            readOnly = true;
            description = "The fully evaluated NixOS configuration for this container.";
            default = evalResult;
          };
        };
    };
}
