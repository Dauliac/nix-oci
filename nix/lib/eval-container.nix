# Shared NixOS container evaluation function.
#
# Pure function callable from both flake-parts (perContainer) and deploy
# (NixOS/home-manager) contexts. Evaluates a NixOS config with the
# nixos-oci module tree and returns the result.
#
# Cycle-safe reads: isRoot, containerName, mainService, package (when
# mainService is null), dependencies.
# NEVER pass: user, name, entrypoint (they depend on eval output).
{ lib }:
let
  inherit (lib) strings;
  identityLib = import ./identity.nix { inherit lib; };
  inherit (identityLib)
    packageName
    parsePasswdFile
    parseGroupFile
    gidToGroupName
    ;

  # Create a NixOS module that declares base image users and groups.
  # All declarations use mkDefault so nix-oci's own users take precedence.
  # Reads from committed source files (pre-extracted at lock update time).
  mkBaseImageUsersModule =
    {
      basePasswdPath,
      baseGroupPath,
    }:
    let
      passwdContent = builtins.readFile basePasswdPath;
      groupContent = builtins.readFile baseGroupPath;

      parsedUsers = parsePasswdFile passwdContent;
      parsedGroups = parseGroupFile groupContent;
      gidMap = gidToGroupName parsedGroups;

      safeInt =
        s:
        let
          r = builtins.tryEval (lib.toInt s);
        in
        if r.success then r.value else 0;
    in
    { lib, ... }:
    {
      users.groups = builtins.listToAttrs (
        map (
          g:
          lib.nameValuePair g.name {
            gid = lib.mkDefault (safeInt g.gid);
          }
        ) parsedGroups
      );

      users.users = builtins.listToAttrs (
        lib.filter (x: x != null) (
          map (
            u:
            let
              uid = safeInt u.uid;
              groupName = gidMap.${u.gid} or u.name;
              isSystem = uid != 0 && uid < 1000;
            in
            # Skip root — nix-oci's users.nix always declares it
            if u.name == "root" then
              null
            else
              lib.nameValuePair u.name (
                {
                  uid = lib.mkDefault uid;
                  group = lib.mkDefault groupName;
                  home = lib.mkDefault u.home;
                }
                // (
                  if isSystem then { isSystemUser = lib.mkDefault true; } else { isNormalUser = lib.mkDefault true; }
                )
              )
          ) parsedUsers
        )
      );
    };

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
  #   ociNixOSModules  - the nixos-oci module tree (import-tree result)
  #   nixosModules     - user-provided nixosConfig.modules
  #   mainService      - nixosConfig.mainService (or null)
  #   homeManagerFlake - homeConfig.homeManagerFlake (or null)
  #   homeModules      - homeConfig.modules (or [])
  #   basePasswdPath   - path to committed base-passwd file (or null)
  #   baseGroupPath    - path to committed base-group file (or null)
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
      nixLibNixosModule ? null,
      homeManagerFlake ? null,
      homeModules ? [ ],
      fromImageEnabled ? false,
      basePasswdPath ? null,
      baseGroupPath ? null,
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
            hmNixosModule = homeManagerFlake.nixosModules.home-manager or homeManagerFlake.nixosModule or null;
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

      # When building on a base image, read pre-extracted /etc/passwd and
      # /etc/group from committed lock files and inject as NixOS user/group
      # declarations. Files are committed by `oci-updatePulledManifestsLocks`.
      baseImageModules =
        if
          fromImageEnabled
          && basePasswdPath != null
          && baseGroupPath != null
          && builtins.pathExists basePasswdPath
          && builtins.pathExists baseGroupPath
        then
          [ (mkBaseImageUsersModule { inherit basePasswdPath baseGroupPath; }) ]
        else
          [ ];

      evalResult =
        (import "${pkgs.path}/nixos/lib/eval-config.nix" {
          inherit (pkgs) system;
          modules = [
            ociNixOSModules
          ]
          ++ lib.optional (nixLibNixosModule != null) nixLibNixosModule
          ++ [
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
                  # dependencies, hardening don't depend on eval -- safe to pass
                  dependencies = containerConfig.dependencies;
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
          ++ baseImageModules
          ++ nixosModules
          ++ homeManagerModules;
        }).config;
    in
    {
      inherit evalResult containerUser;
    };
}
