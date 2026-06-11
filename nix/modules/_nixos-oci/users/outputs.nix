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
    assertions = [
      {
        assertion = !(cfg.isRoot && cfg.user != "root");
        message = ''
          nix-oci: `isRoot = true` but `user = "${cfg.user}"` (expected "root").
          When running as root, the user must be "root". Either:
            - Set `user = "root"` (or leave it at default)
            - Set `isRoot = false` to run as a non-root user
        '';
      }
      {
        assertion = !(cfg.isRoot && cfg.uid != 0 && cfg.uid != 4000);
        message = ''
          nix-oci: `isRoot = true` but `uid = ${toString cfg.uid}` (expected 0).
          When running as root, do not set a custom uid. Either:
            - Remove the `uid` setting (root always uses UID 0)
            - Set `isRoot = false` to run as a non-root user
        '';
      }
      {
        assertion = !(cfg.isRoot && cfg.gid != 0 && cfg.gid != 4000);
        message = ''
          nix-oci: `isRoot = true` but `gid = ${toString cfg.gid}` (expected 0).
          When running as root, do not set a custom gid. Either:
            - Remove the `gid` setting (root always uses GID 0)
            - Set `isRoot = false` to run as a non-root user
        '';
      }
      {
        assertion = cfg.isRoot || cfg.user != "root";
        message = ''
          nix-oci: `user = "root"` but `isRoot = false`.
          If you intend to run as root, set `isRoot = true`.
          If you intend to run as a non-root user, change `user` to a non-root name.
        '';
      }
    ];
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
        group = lib.mkForce cfg.user;
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
