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

  # Home-manager guard & defaults module for container environments.
  # Extracted to its own file with oci.container.* namespace for
  # identity binding and assertions.
  hmContainerDefaults = ../modules/_home-manager-oci/defaults.nix;
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
                      # Bind nixos-oci identity → HM oci.container namespace
                      oci.container = {
                        user = nixosEvalUser;
                        homeDirectory = if containerIsRoot then "/root" else "/home/${nixosEvalUser}";
                        name = containerName;
                      };
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
        if fromImageEnabled then
          if basePasswdPath == null || baseGroupPath == null then
            builtins.throw ''
              nix-oci: container "${containerName}" has `fromImage` set but base image
              identity paths are not configured.
              Both `basePasswdPath` and `baseGroupPath` must be set when building on
              a base image. Run `nix run .#oci-updatePulledManifestsLocks` to extract
              the base image's /etc/passwd and /etc/group files.
            ''
          else if !(builtins.pathExists basePasswdPath) then
            builtins.throw ''
              nix-oci: container "${containerName}" has `fromImage` set but the base
              image passwd file does not exist: ${toString basePasswdPath}
              Run `nix run .#oci-updatePulledManifestsLocks` to extract base image
              identity files, then commit the result.
            ''
          else if !(builtins.pathExists baseGroupPath) then
            builtins.throw ''
              nix-oci: container "${containerName}" has `fromImage` set but the base
              image group file does not exist: ${toString baseGroupPath}
              Run `nix run .#oci-updatePulledManifestsLocks` to extract base image
              identity files, then commit the result.
            ''
          else
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
            # Forward container options to the NixOS eval.
            #
            # Options are declared by container-options-namespace.nix (from _options/)
            # and NixOS-only files (users, entrypoint, nix-support, base).
            #
            # Generic forward: pass all Tier 1 fields from containerConfig.
            # mkIf guards prevent overriding service adapter mkDefault values
            # with null/[] defaults.
            (
              { lib, ... }:
              {
                nixpkgs.hostPlatform = lib.mkDefault pkgs.system;
                oci.container = {
                  # Identity (cycle-safe)
                  inherit (containerConfig) package dependencies uid gid;
                  user = nixosEvalUser;
                  isRoot = containerIsRoot;
                  inherit mainService fromImageEnabled;
                  installNix = containerConfig.installNix or false;

                  # Runtime (mkIf guards for nullable/empty fields)
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

                  # Hardening and GPU — forward entire sub-configs
                  inherit (containerConfig) hardening gpu;

                  # Performance — forward Tier 1 only (exclude Tier 2: compression, march, hwcaps, turbo)
                  performance = builtins.removeAttrs (containerConfig.performance or { }) [
                    "compression"
                    "march"
                    "hwcaps"
                    "turbo"
                    "runtime"
                  ];
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
