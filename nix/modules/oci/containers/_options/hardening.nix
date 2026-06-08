# Shared: container security hardening.
#
# Three independent security layers using different kernel primitives:
#   - Seccomp: syscall filtering (BPF at syscall boundary)
#   - Landlock: object-level access control (LSM hooks at VFS/network level)
#   - Capabilities + runtime flags: privilege restriction
#
# Build-time options (disableDns, noTlsTrustStore, seccomp, landlock) are
# baked into the image. Runtime hints (capabilities, readOnlyRootfs,
# noNewPrivileges) are embedded as labels and applied by deploy modules.
{ lib, ... }:
{
  options.hardening = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable container security hardening.
            Applies build-time filesystem restrictions and generates
            runtime security hints consumed by deploy modules.
          '';
        };

        # -- Build-time filesystem hardening --

        disableDns = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Disable DNS resolution inside the container.
            Sets `/etc/resolv.conf` to empty and `/etc/nsswitch.conf`
            hosts line to `files` only. Applications using IP addresses
            directly are unaffected.

            In the inner NixOS module, this overrides the default
            nsswitch.conf to remove the `dns` backend.
          '';
        };

        noTlsTrustStore = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Remove the TLS certificate trust store (`/etc/ssl/certs`).
            Prevents all outgoing HTTPS connections. Only use for
            containers that never initiate TLS.
          '';
        };

        # -- Seccomp: syscall filtering --

        seccomp = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable a custom seccomp profile for this container.";
              };

              profile = lib.mkOption {
                type = lib.types.enum [
                  "strict"
                  "moderate"
                  "web-server"
                ];
                default = "moderate";
                description = ''
                  Predefined seccomp profile level:

                  - `"strict"` — allowlist of ~60 syscalls. Suitable for
                    static binaries, Go/Rust services. Blocks `execve`,
                    `mount`, `ptrace`, and most process/namespace ops.

                  - `"moderate"` — blocks ~44 dangerous syscalls (similar
                    to Docker's default). Allows most normal operations.

                  - `"web-server"` — strict base plus networking and
                    threading syscalls. Suitable for HTTP servers.

                  In the inner NixOS module, the profile auto-defaults
                  to `"web-server"` when a web server service (nginx,
                  httpd) is detected.
                '';
              };

              customProfileJson = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = ''
                  Path to a custom seccomp profile JSON file following
                  the OCI runtime specification format. When set,
                  overrides `profile`.
                '';
              };
            };
          };
          default = { };
          description = "Seccomp syscall filtering configuration.";
        };

        # -- Landlock: object-level access control --

        landlock = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Enable Landlock LSM restrictions. Requires Linux >= 5.13
                  (filesystem) or >= 6.7 (TCP network).

                  Embeds a Landlock wrapper in the container entrypoint
                  that self-restricts filesystem and network access before
                  executing the real application. Unlike seccomp (which
                  filters syscalls) and namespaces (which control
                  visibility), Landlock controls *which specific resources*
                  (inodes, ports) a process can access.
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
            Landlock LSM access control configuration.
            Operates on a different kernel primitive than seccomp or
            namespaces — hooks at the VFS/object level after path
            resolution, so it can restrict *which* files are accessible,
            not just *which syscalls* are allowed.
          '';
        };

        # -- Runtime hints (deploy modules apply these) --

        capabilities = lib.mkOption {
          type = lib.types.submodule {
            options = {
              drop = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "ALL" ];
                description = ''
                  Linux capabilities to drop. Defaults to `["ALL"]`.
                  Deploy modules translate to `--cap-drop`.
                '';
              };

              add = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = ''
                  Linux capabilities to add back after dropping.
                  Deploy modules translate to `--cap-add`.
                '';
                example = [ "NET_BIND_SERVICE" ];
              };
            };
          };
          default = { };
          description = "Linux capability restrictions applied at runtime.";
        };

        readOnlyRootfs = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Mount the container root filesystem as read-only at runtime.
            Deploy modules translate to `--read-only`. Prevents attackers
            from writing malware or achieving persistence.
          '';
        };

        noNewPrivileges = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Set the `no_new_privs` bit. Prevents privilege escalation
            via setuid/setgid binaries. Deploy modules translate to
            `--security-opt=no-new-privileges`.
          '';
        };
      };
    };
    default = { };
    description = ''
      Container security hardening configuration.

      Controls build-time image hardening (filesystem restrictions,
      seccomp profiles, Landlock policies) and runtime hints
      (capabilities, read-only rootfs, noNewPrivileges) that deploy
      modules apply.

      For containers using `nixosConfig`, these options are forwarded
      to the inner NixOS module at `oci.container.hardening` and can
      be overridden through NixOS module composition.
    '';
  };
}
