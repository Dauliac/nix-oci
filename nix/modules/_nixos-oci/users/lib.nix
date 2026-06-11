{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;
in
{
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
}
