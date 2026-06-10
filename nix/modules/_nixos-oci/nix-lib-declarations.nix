# nix-lib function declarations for the nixos-oci module scope.
#
# Declares functions via nix-lib.lib.oci.container.* so they are:
# - Typed and documented
# - Available at config.lib.oci.container.* within the eval
# - Collected as _libsMeta for documentation
#
# This file is prefixed with _ so import-tree doesn't auto-import it
# into flake-parts. It's imported explicitly via the _nixos-oci module tree.
#
# NOTE: This file requires the nix-lib NixOS adapter to be imported
# in the evaluation. Without it, nix-lib.lib.* options don't exist.
{ lib, ... }:
{
  config.nix-lib.enable = true;
  config.nix-lib.lib.oci.container = {
    allocatorMeta = {
      type = lib.types.functionTo lib.types.attrs;
      description = ''
        Map allocator name to `{ package, soName }`.
        Returns `{ package = null; soName = null; }` when allocator is null.

        Takes `{ allocator, pkgs }`.
      '';
      fn =
        {
          allocator,
          pkgs,
        }:
        if allocator == "mimalloc" then
          {
            package = pkgs.mimalloc;
            soName = "libmimalloc.so";
          }
        else if allocator == "tcmalloc" then
          {
            package = pkgs.gperftools;
            soName = "libtcmalloc.so";
          }
        else
          {
            package = null;
            soName = null;
          };
    };

    mkGlibcTunablesStr = {
      type = lib.types.functionTo lib.types.str;
      description = "Format glibc tunables attrset as GLIBC_TUNABLES env value (KEY=VALUE:KEY=VALUE).";
      fn =
        tunables: lib.concatStringsSep ":" (lib.mapAttrsToList (name: value: "${name}=${value}") tunables);
      tests = {
        "formats single tunable" = {
          args = {
            "glibc.malloc.mmap_threshold" = "131072";
          };
          expected = "glibc.malloc.mmap_threshold=131072";
        };
      };
    };

    mkMinimalBinSh = {
      type = lib.types.functionTo lib.types.package;
      description = ''
        Create a minimal /bin/sh derivation for healthcheck execution.
        Podman runs --health-cmd via "sh -c <cmd>", so /bin/sh must exist.
        Links /bin/sh → bash without pulling in full bashInteractive closure.
      '';
      fn =
        pkgs:
        pkgs.runCommand "bin-sh" { } ''
          mkdir -p $out/bin
          ln -s ${pkgs.bashInteractive}/bin/bash $out/bin/sh
        '';
    };

    runtimeOverriddenEtcNames = {
      type = lib.types.listOf lib.types.str;
      description = ''
        List of /etc file names that container runtimes always bind-mount
        at startup, masking any content baked into the image layer.
        Includes resolv.conf, hostname, hosts.
      '';
      fn = [
        "resolv.conf"
        "hostname"
        "hosts"
      ];
    };
  };
}
