# Nix-in-container support: nixbld users, nix.conf, packages, /nix/var dirs
#
# When oci.container.installNix is true, this module:
# - Creates 32 nixbld build users and the nixbld group (via NixOS users module)
# - Creates a nobody user (required by Nix)
# - Configures /etc/nix/nix.conf with flakes enabled
# - Adds nix, bash, coreutils to environment.systemPackages
# - Provides /nix/var directory derivation and permissions as outputs
#
# This replaces the hand-written mkNixShadowSetup and mkNixOCILayer shadow
# setup, leveraging the NixOS module system for proper composition with
# service adapters (e.g. nginx user + nixbld users in the same /etc/passwd).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
  numBuildUsers = 32;
in
{
  options.oci.container.installNix = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install Nix in the container.";
  };

  options.oci.container._output.nixVarDirs = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    internal = true;
    readOnly = true;
    description = "Derivation creating /nix/var/nix directories for Nix profiles and gc roots.";
    default =
      if cfg.installNix then
        pkgs.runCommand "nix-var-dirs" { } ''
          mkdir -p $out/nix/var/nix/profiles/per-user/${cfg.user}
          mkdir -p $out/nix/var/nix/gcroots/per-user/${cfg.user}
          mkdir -p $out/nix/var/nix/temproots
        ''
      else
        null;
  };

  options.oci.container._output.nixPerms = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    internal = true;
    readOnly = true;
    description = "nix2container perms entries for /nix/var when non-root.";
    default =
      if cfg.installNix && !cfg.isRoot then
        [
          {
            path = cfg._output.nixVarDirs;
            regex = "/nix/var/nix/.*";
            mode = "0755";
            uid = cfg.uid;
            gid = cfg.gid;
          }
        ]
      else
        [ ];
  };

  config = lib.mkIf cfg.installNix {
    # Nix build users -- NixOS users module generates /etc/passwd entries
    users.users = {
      nobody = {
        isSystemUser = true;
        group = lib.mkForce "nobody";
        uid = lib.mkForce 65534;
        home = "/var/empty";
      };
    }
    // builtins.listToAttrs (
      builtins.genList (
        i:
        let
          n = i + 1;
        in
        {
          name = "nixbld${toString n}";
          value = {
            isSystemUser = true;
            group = "nixbld";
            uid = 30000 + n;
            home = "/var/empty";
          };
        }
      ) numBuildUsers
    );

    users.groups = {
      nobody.gid = 65534;
      nixbld.gid = 30000;
    };

    # Nix configuration
    environment.etc."nix/nix.conf".text = lib.mkDefault ''
      experimental-features = nix-command flakes
    '';

    # Nix packages -- included in _output.rootFilesystem via systemPackages
    environment.systemPackages = [
      pkgs.nix
      pkgs.bashInteractive
      pkgs.coreutils
      # /bin/sh symlink for tools that expect a POSIX shell
      (pkgs.runCommand "fhs-sh" { } ''
        mkdir -p $out/bin
        ln -s ${pkgs.bashInteractive}/bin/bash $out/bin/sh
      '')
    ];
  };
}
