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
      description = ''
        Generate a passwd line from a user name and attrset, given a
        groups attrset for the gid lookup. Taking groups as a parameter
        (instead of reading `config.users.groups` directly) lets callers
        pass the backfilled attrset from `allocateMissingIds`, so system
        users whose nixpkgs module did not set an explicit gid still
        resolve to a stable allocated value instead of null (which
        `toString` cannot coerce to a string and which turns the
        emitted /etc/passwd line into a malformed garbage entry nss
        then fails to parse - the real root cause of `chown: invalid
        user: 'dnsmasq'` crash loops at container boot).
      '';
      default =
        groups: name: u:
        let
          rawGid = groups.${u.group}.gid or null;
          gid = if rawGid != null then toString rawGid else "0";
        in
        "${name}:x:${toString u.uid}:${gid}::${u.home}:/bin/nologin";
    };

    # High-system-user pool for container `/etc/passwd` and
    # `/etc/group` emission.
    #
    # NixOS allocates UIDs/GIDs for `isSystemUser = true` users at
    # system-activation time; inside a container there is no
    # activation script, so any system user whose nixpkgs module
    # does not set an explicit uid (e.g. `services.dnsmasq`, which
    # lacks a `config.ids.uids.dnsmasq` entry) would otherwise be
    # silently dropped from the shadow files. The container's
    # systemd unit then fails with `chown: invalid user: '<svc>'`
    # on startup and crash-loops. `allocateMissingIds` walks the
    # declared users / groups and assigns a stable id from the
    # pool to anyone missing one, so every declared principal ends
    # up in the shadow files.
    #
    # Pool choice:
    #   - Starts at 999 and counts down. Explicit nixpkgs uids live
    #     in the 60..300 range (`<nixpkgs>/nixos/modules/misc/ids.nix`);
    #     500..999 is unused by the modules we rely on and small
    #     enough to never overflow for a single container.
    #   - Sort by name so the id assigned to a given user does not
    #     drift across evals when unrelated attrs change.
    idPoolStart = lib.mkOption {
      type = lib.types.ints.positive;
      internal = true;
      readOnly = true;
      description = "First id handed out by allocateMissingIds (counts down).";
      default = 999;
    };

    allocateMissingIds = lib.mkOption {
      type = lib.types.unspecified;
      internal = true;
      readOnly = true;
      description = ''
        Assign a stable id from the pool to any entry in `attr` whose
        `field` is `null`. Takes `{ attr, field, poolStart }` and
        returns an attrset with the same shape as `attr` where every
        entry has `field` set to either its original value or an
        allocated one. Deterministic across evals (sorted by name).
      '';
      default =
        {
          attr,
          field,
          poolStart ? config.oci.lib.idPoolStart,
        }:
        let
          missing = lib.sort builtins.lessThan (
            lib.attrNames (lib.filterAttrs (_: v: v.${field} == null) attr)
          );
          assigned = lib.listToAttrs (
            lib.imap0 (i: name: {
              inherit name;
              value = poolStart - i;
            }) missing
          );
        in
        lib.mapAttrs (
          name: v:
          v
          // {
            ${field} = if v.${field} != null then v.${field} else assigned.${name} or null;
          }
        ) attr;
    };
  };
}
