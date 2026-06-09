# OCI mkLandlockPolicy - Generate a Landlock policy JSON
#
# Landlock operates at the VFS/object level using three kernel syscalls:
#   landlock_create_ruleset → landlock_add_rule → landlock_restrict_self
#
# The policy JSON describes allowed paths and ports. A Landlock wrapper
# binary reads this policy and applies it before exec'ing the real
# entrypoint. This is a deny-by-default, irreversible restriction.
#
# Unlike seccomp (which filters syscalls) or namespaces (which control
# visibility), Landlock controls *which specific inodes and ports* a
# process can access -- a genuinely different kernel primitive.
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkLandlockPolicy = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Generate a Landlock policy JSON file from hardening configuration.

          The policy describes:
          - `fs.read`: paths allowed for reading
          - `fs.write`: paths allowed for writing
          - `fs.execute`: paths allowed for execution
          - `net.connectTcp`: ports allowed for outgoing TCP
          - `net.bindTcp`: ports allowed for TCP bind/listen

          Returns a store path to the JSON file, intended for consumption
          by a Landlock wrapper binary in the container entrypoint.
        '';
        file = "nix/modules/oci/lib/mkLandlockPolicy.nix";
        fn =
          {
            name,
            hardening,
          }:
          let
            policy = {
              version = 1;
              fs = {
                read = hardening.landlock.allowedReadPaths;
                write = hardening.landlock.allowedWritePaths;
                execute = hardening.landlock.allowedExecutePaths;
              };
              net = {
                connectTcp = hardening.landlock.allowedTcpConnect;
                bindTcp = hardening.landlock.allowedTcpBind;
              };
            };
          in
          pkgs.writeText "landlock-${name}.json" (builtins.toJSON policy);
      };
    };
}
