# Per-container: mount host Nix store and optionally the daemon socket.
#
# Convenience options that set well-known `bindMounts` entries,
# mirroring how NixOS containers automatically bind-mount
# /nix/store, /nix/var/nix/db, and /nix/var/nix/daemon-socket.
#
# `nix.hostStore` mounts the store read-only — the container can run
# any closure present on the host without embedding it in the image.
#
# `nix.hostDaemon` also mounts the daemon socket and db, so the
# container can build derivations via the host nix-daemon.
# No nixbld users needed inside the container.
{
  lib,
  config,
  ...
}:
let
  cfg = config.nix;
  hostNixEnabled = cfg.hostStore || cfg.hostDaemon;
in
{
  options.nix = {
    hostStore = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Bind-mount the host `/nix/store` read-only into the container.
        Gives the container access to all store paths on the host
        without copying them into the image.

        Mutually exclusive with `installNix`.
      '';
    };

    hostDaemon = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Bind-mount the host nix-daemon socket and Nix database into
        the container. Allows `nix build`, `nix develop`, etc.
        using the host daemon. Implies `nix.hostStore = true`.
      '';
    };

    gcRoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Register the container's closure as a GC root on the host.
        Prevents the host garbage collector from removing store paths
        that the running container depends on.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf hostNixEnabled {
      bindMounts."/nix/store" = {
        isReadOnly = true;
      };
    })

    (lib.mkIf cfg.hostDaemon {
      bindMounts."/nix/var/nix/db" = {
        isReadOnly = true;
      };
      bindMounts."/nix/var/nix/daemon-socket" = {
        isReadOnly = true;
      };

      environment.NIX_REMOTE = "daemon";
    })
  ];
}
