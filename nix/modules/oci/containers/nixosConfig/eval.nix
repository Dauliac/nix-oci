# Container nixosConfig.eval - unified NixOS evaluation
#
# Imports nix/nixos/oci-container.nix, passes container options, merges
# user's nixosConfig.modules and homeConfig.modules.
#
# User derivation leverages Nix laziness to resolve from the service
# package without an explicit cycle: evalResult.services.${mainService}.package
# doesn't access oci.container.user, so the circular let-binding never
# triggers infinite recursion.
#
# Cycle-safe reads: isRoot, _containerName, mainService, package (when
# mainService is null), dependencies, configFiles.
# NEVER reads: user, name, entrypoint (they depend on eval).
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

          # Resolve package identity for user name: pname -> parsed drv name
          # Unlike image naming (which uses mainProgram), user names should
          # reflect the package identity (e.g. "redis" not "redis-cli").
          packageName =
            pkg:
            if pkg.pname or null != null then
              pkg.pname
            else
              (builtins.parseDrvName (pkg.name or "unknown")).name;

          # Derive container user from the actual service package when possible.
          # Priority: service package → explicit package → _containerName.
          # Truncate to 31 chars — NixOS rejects user/group names longer than that.
          #
          # When mainService is set, we read evalResult.services.${mainService}.package.
          # This is a lazy circular reference (containerUser ↔ evalResult), but safe:
          # services.*.package defaults to pkgs.<name> and never accesses oci.container.user.
          containerUser =
            if containerIsRoot then
              "root"
            else
              builtins.substring 0 31 (
                lib.strings.toLower (
                  let
                    # services.${mainService} may not exist for nested services
                    # (e.g. redis-default lives at services.redis.servers.default)
                    servicePkg =
                      if mainService != null && evalResult.services ? ${mainService} then
                        evalResult.services.${mainService}.package or null
                      else
                        null;
                  in
                  if servicePkg != null then
                    packageName servicePkg
                  else if config.package != null then
                    packageName config.package
                  else
                    config._containerName
                )
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
                      # dependencies, configFiles, hardening don't depend on eval — safe to pass
                      dependencies = config.dependencies;
                      configFiles = config.configFiles;
                      # Forward build-time hardening options (not runtime hints like
                      # capabilities/readOnlyRootfs which are applied by deploy modules).
                      hardening = {
                        inherit (config.hardening)
                          enable
                          disableDns
                          noTlsTrustStore
                          seccomp
                          landlock
                          ;
                      };
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
