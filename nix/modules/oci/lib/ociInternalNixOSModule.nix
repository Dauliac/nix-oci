# oci-internal NixOS module
#
# This NixOS module is always included in every container's NixOS eval.
# It translates nix-oci container options into proper NixOS configuration,
# providing a single source of truth for:
# - User/group management (passwd, group, shadow, gshadow, nsswitch)
# - Environment variables (PATH, HOME, USER, SSL_CERT_FILE)
# - Base packages (cacert)
# - Home directory setup
#
# This replaces the hand-written mkRootShadowSetup, mkNonRootShadowSetup,
# and hardcoded env vars that were previously scattered across the codebase.
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkOCIInternalNixOSModule = {
        type = lib.types.functionTo lib.types.unspecified;
        description = "Generate the internal NixOS module for a container from its oci options";
        fn =
          {
            user,
            isRoot,
            uid ? 4000,
            gid ? 4000,
          }:
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            homeDir = if isRoot then "/root" else "/home/${user}";
          in
          {
            boot.isContainer = true;

            documentation.enable = lib.mkDefault false;
            documentation.man.enable = lib.mkDefault false;
            documentation.nixos.enable = lib.mkDefault false;
            system.stateVersion = lib.mkDefault "25.05";
            nixpkgs.hostPlatform = lib.mkDefault pkgs.system;

            # User management — single source of truth for shadow files
            users.mutableUsers = false;

            users.users = {
              root = {
                isSystemUser = true;
                home = "/root";
                group = "root";
                uid = 0;
              };
            }
            // lib.optionalAttrs (!isRoot) {
              ${user} = {
                isNormalUser = true;
                home = homeDir;
                uid = uid;
                group = user;
              };
            };

            users.groups = {
              root.gid = 0;
            }
            // lib.optionalAttrs (!isRoot) {
              ${user}.gid = gid;
            };

            # Environment
            environment.variables = {
              SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
            };

            # SSL certificates
            security.pki.certificateFiles = [ ];
            environment.etc."ssl/certs/ca-bundle.crt".source =
              lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

            # NSSwitch for glibc resolution
            environment.etc."nsswitch.conf".text = lib.mkDefault ''
              passwd:    files
              group:     files
              shadow:    files
              hosts:     files dns
              networks:  files
              ethers:    files
              services:  files
              protocols: files
              rpc:       files
            '';
          };
      };
    };
}
