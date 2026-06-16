# Shared: Landlock LSM object-level access control.
#
# Landlock hooks at the VFS level *after* path resolution, operating on
# resolved inodes and TCP port numbers. This is a fundamentally different
# primitive from seccomp (syscall filtering) and namespaces (visibility):
#
#   Namespaces → what you can SEE
#   Seccomp    → which OPERATIONS you can invoke
#   Landlock   → which specific RESOURCES you can touch
#
# Landlock is unprivileged, self-imposed, and irreversible once applied.
# It survives execve -- child processes inherit restrictions.
# Requires Linux >= 5.13 (filesystem) or >= 6.7 (TCP network).
{
  lib,
  ...
}:
{
  options.hardening.landlock = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable Landlock LSM restrictions. Embeds a Landlock
            wrapper in the container entrypoint that self-restricts
            filesystem and network access before executing the real
            application.
          '';
        };

        allowedReadPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Filesystem paths allowed for reading. When empty and
            `enable` is `true`, auto-populated from the Nix closure
            of the container's package and dependencies.
          '';
        };

        allowedWritePaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Filesystem paths allowed for writing (e.g. `/tmp`, `/var/log`).";
        };

        allowedExecutePaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Filesystem paths allowed for execution. Auto-populated
            from the package's `/bin` directory when empty.
          '';
        };

        allowedTcpConnect = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [ ];
          description = "TCP ports allowed for outgoing `connect()`.";
        };

        allowedTcpBind = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [ ];
          description = "TCP ports allowed for `bind()`/`listen()`.";
        };
      };
    };
    default = { };
    description = ''
      Landlock LSM access control. Operates at the VFS/object level
      after path resolution -- can restrict *which* files and ports
      are accessible, not just *which syscalls* are allowed.
    '';
  };
}
