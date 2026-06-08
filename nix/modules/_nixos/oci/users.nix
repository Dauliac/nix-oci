# User management: options, lib, config, and shadow file output
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
    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Container user name.";
    };
    isRoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the container runs as root.";
    };
    uid = lib.mkOption {
      type = lib.types.int;
      default = 4000;
      description = "UID for non-root container user.";
    };
    gid = lib.mkOption {
      type = lib.types.int;
      default = 4000;
      description = "GID for non-root container user.";
    };
  };

  options.oci.lib = {
    homeDir = lib.mkOption {
      type = lib.types.str;
      internal = true;
      readOnly = true;
      description = "Computed home directory path for the container user.";
      default = if cfg.isRoot then "/root" else "/home/${cfg.user}";
    };

    mkShadowEntry = lib.mkOption {
      type = lib.types.unspecified;
      internal = true;
      readOnly = true;
      description = "Generate a passwd line from a user name and attrset.";
      default =
        name: u:
        let
          gid = toString (config.users.groups.${u.group}.gid or 0);
        in
        "${name}:x:${toString u.uid}:${gid}::${u.home}:";
    };
  };

  options.oci.container._output.shadowFiles = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    internal = true;
    readOnly = true;
    description = "Generated passwd/group/shadow/gshadow derivations.";
    default =
      let
        users = config.users.users;
        groups = config.users.groups;
      in
      [
        (pkgs.writeTextDir "etc/passwd" (
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList config.oci.lib.mkShadowEntry (lib.filterAttrs (_: u: u.uid != null) users)
          )
        ))
        (pkgs.writeTextDir "etc/group" (
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: g: "${name}:x:${toString g.gid}:") (
              lib.filterAttrs (_: g: g.gid != null) groups
            )
          )
        ))
        (pkgs.writeTextDir "etc/shadow" (
          lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: "${name}:!:::::::") users)
        ))
        (pkgs.writeTextDir "etc/gshadow" (
          lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: "${name}:x::") groups)
        ))
      ];
  };

  config = {
    users.mutableUsers = false;
    users.users = {
      root = {
        isSystemUser = true;
        home = "/root";
        group = "root";
        uid = 0;
      };
    }
    // lib.optionalAttrs (!cfg.isRoot) {
      ${cfg.user} = {
        isNormalUser = lib.mkDefault true;
        home = lib.mkDefault config.oci.lib.homeDir;
        uid = lib.mkDefault cfg.uid;
        group = lib.mkDefault cfg.user;
      };
    };
    users.groups = {
      root.gid = 0;
    }
    // lib.optionalAttrs (!cfg.isRoot) {
      ${cfg.user}.gid = lib.mkDefault cfg.gid;
    };
  };
}
