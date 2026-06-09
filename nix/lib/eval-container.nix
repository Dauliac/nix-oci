# Shared NixOS container evaluation function.
#
# Pure function callable from both flake-parts (perContainer) and deploy
# (NixOS/home-manager) contexts. Evaluates a NixOS config with the
# _nixos/oci module tree and returns the result.
#
# Cycle-safe reads: isRoot, containerName, mainService, package (when
# mainService is null), dependencies, configFiles.
# NEVER pass: user, name, entrypoint (they depend on eval output).
{ lib }:
let
  inherit (lib) strings;

  # Resolve package identity for user name: pname -> parsed drv name.
  # Unlike image naming (which uses mainProgram), user names should
  # reflect the package identity (e.g. "redis" not "redis-cli").
  packageName =
    pkg:
    if pkg.pname or null != null then
      pkg.pname
    else
      (builtins.parseDrvName (pkg.name or "unknown")).name;

  # Internal home-manager defaults for container environments.
  # All use mkDefault so user modules can override.
  hmContainerDefaults =
    { lib, ... }:
    {
      programs.bash = {
        enable = lib.mkDefault true;
        historySize = lib.mkDefault 10000;
        historyFileSize = lib.mkDefault 100000;
        shellAliases = lib.mkDefault {
          ll = "ls -la";
          la = "ls -A";
          l = "ls -CF";
        };
      };

      programs.starship = {
        enable = lib.mkDefault true;
        enableBashIntegration = lib.mkDefault true;
        settings = {
          add_newline = lib.mkDefault false;
          format = lib.mkDefault "$username$hostname$directory$git_branch$git_status$nix_shell$container$character";
          character = {
            success_symbol = lib.mkDefault "[➜](bold green)";
            error_symbol = lib.mkDefault "[✗](bold red)";
          };
          container = {
            format = lib.mkDefault "[$symbol \\($name\\)]($style) ";
            symbol = lib.mkDefault "⬡";
            style = lib.mkDefault "bold dimmed blue";
          };
          directory = {
            truncation_length = lib.mkDefault 3;
            truncate_to_repo = lib.mkDefault false;
          };
          username = {
            show_always = lib.mkDefault true;
            format = lib.mkDefault "[$user]($style)@";
          };
          hostname = {
            ssh_only = lib.mkDefault false;
            format = lib.mkDefault "[$hostname]($style):";
          };
          nix_shell = {
            symbol = lib.mkDefault "❄️ ";
          };
        };
      };

      home.sessionVariables = {
        TERM = lib.mkDefault "xterm-256color";
      };
    };
in
{
  # Evaluate a NixOS container configuration.
  #
  # Arguments:
  #   pkgs             - nixpkgs package set
  #   containerName    - container attribute name (fallback for user derivation)
  #   containerConfig  - resolved container option values (cycle-safe subset)
  #   ociNixOSModules  - the _nixos/oci module tree (import-tree result)
  #   nixosModules     - user-provided nixosConfig.modules
  #   mainService      - nixosConfig.mainService (or null)
  #   homeManagerFlake - homeConfig.homeManagerFlake (or null)
  #   homeModules      - homeConfig.modules (or [])
  #
  # Returns: { evalResult; containerUser; }
  #   evalResult   - the fully evaluated NixOS .config
  #   containerUser - the derived container user name
  evalContainerNixos =
    {
      pkgs,
      containerName,
      containerConfig,
      ociNixOSModules,
      nixosModules ? [ ],
      mainService ? null,
      homeManagerFlake ? null,
      homeModules ? [ ],
      fromImageEnabled ? false,
    }:
    let
      containerIsRoot = containerConfig.isRoot;

      # Derive container user from the actual service package when possible.
      # Priority: service package → explicit package → containerName.
      # Truncate to 31 chars -- NixOS rejects user/group names longer than that.
      #
      # When mainService is set, we read evalResult.services.${mainService}.package.
      # This is a lazy circular reference (containerUser ↔ evalResult), but safe:
      # services.*.package defaults to pkgs.<name> and never accesses oci.container.user.
      containerUser =
        if containerIsRoot then
          "root"
        else
          builtins.substring 0 31 (
            strings.toLower (
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
              else if containerConfig.package != null then
                packageName containerConfig.package
              else
                containerName
            )
          );

      # When mainService is null, config.user is safe to read because
      # its mkDefault (containerUser) doesn't depend on evalResult.
      # When mainService is set, we must use containerUser directly to
      # avoid a cycle: config.user → containerUser → evalResult → config.user.
      nixosEvalUser =
        if mainService == null then containerConfig.user or containerUser else containerUser;

      # Build home-manager NixOS modules when a HM flake is provided.
      homeManagerModules =
        if homeManagerFlake != null then
          let
            hmNixosModule =
              homeManagerFlake.nixosModules.home-manager
                or homeManagerFlake.nixosModule
                or null;
          in
          if hmNixosModule != null then
            [
              hmNixosModule
              (
                { lib, ... }:
                {
                  home-manager.useGlobalPkgs = lib.mkDefault true;
                  home-manager.useUserPackages = lib.mkDefault true;
                  home-manager.users.${nixosEvalUser} =
                    { lib, ... }:
                    {
                      imports = [ hmContainerDefaults ] ++ homeModules;
                      home.stateVersion = lib.mkDefault "25.05";
                    };
                }
              )
            ]
          else
            builtins.throw "homeConfig.homeManagerFlake does not provide nixosModules.home-manager"
        else
          [ ];

      evalResult =
        (import "${pkgs.path}/nixos/lib/eval-config.nix" {
          inherit (pkgs) system;
          modules =
            [
              ociNixOSModules
              # Pass cycle-safe container options into the NixOS module
              (
                { lib, ... }:
                {
                  nixpkgs.hostPlatform = lib.mkDefault pkgs.system;
                  oci.container = {
                    package = containerConfig.package;
                    user = nixosEvalUser;
                    isRoot = containerIsRoot;
                    inherit mainService fromImageEnabled;
                    installNix = containerConfig.installNix or false;
                    # dependencies, configFiles, hardening don't depend on eval -- safe to pass
                    dependencies = containerConfig.dependencies;
                    configFiles = containerConfig.configFiles;
                    # Forward user-provided OCI metadata so the NixOS eval merges
                    # them with auto-derived values. Use mkIf to avoid overriding
                    # service adapter mkDefault values with null/[] defaults.
                    inherit (containerConfig) environment;
                    entrypoint = lib.mkIf (containerConfig.entrypoint != [ ]) containerConfig.entrypoint;
                    stopSignal = lib.mkIf (containerConfig.stopSignal != null) containerConfig.stopSignal;
                    workingDir = lib.mkIf (containerConfig.workingDir != null) containerConfig.workingDir;
                    declaredVolumes = lib.mkIf (containerConfig.declaredVolumes != [ ]) containerConfig.declaredVolumes;
                    healthcheck = lib.mkIf (containerConfig.healthcheck.command != [ ]) {
                      inherit (containerConfig.healthcheck)
                        command
                        interval
                        timeout
                        startPeriod
                        retries
                        ;
                    };
                    # Forward build-time hardening options (not runtime hints like
                    # capabilities/readOnlyRootfs which are applied by deploy modules).
                    hardening = {
                      inherit (containerConfig.hardening)
                        enable
                        disableDns
                        noTlsTrustStore
                        seccomp
                        landlock
                        ;
                    };
                    # Forward arch-independent performance options.
                    # Arch-specific options (march, hwcaps) are consumed directly
                    # by image builders via archConfigs, not the NixOS eval.
                    performance = {
                      inherit (containerConfig.performance)
                        enable
                        allocator
                        glibcTunables
                        ;
                    };
                  };
                }
              )
            ]
            ++ nixosModules
            ++ homeManagerModules;
        }).config;
    in
    {
      inherit evalResult containerUser;
    };
}
