# Register NixOS eval helper functions in flake-parts nix-lib.
#
# These are the pure cores of functions used inside _nixos-oci (the transient
# NixOS eval). The transient eval can't contribute to nix-lib docs, so we
# expose these here via flake-parts where they're auto-collected.
#
# Provides `config.lib.oci.nixos.{toList,mkEntrypointScript,mkEtcDerivation}`.
# Pure library: nix/lib/oci.nix
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.nixos = {
        toList = {
          type = lib.types.functionTo lib.types.anything;
          description = ''
            Normalize a value to a list.
            - `null` → `[]`
            - scalar `x` → `[x]`
            - list → unchanged

            Used internally by `extractServiceData` to handle systemd
            serviceConfig fields that can be null, a string, or a list.
          '';
          file = "nix/lib/oci.nix";
          fn = pure.toList;
          tests = {
            "null to empty list" = {
              args = null;
              expected = [ ];
            };
            "scalar to singleton" = {
              args = "hello";
              expected = [ "hello" ];
            };
            "list unchanged" = {
              args = [
                "a"
                "b"
              ];
              expected = [
                "a"
                "b"
              ];
            };
            "empty list unchanged" = {
              args = [ ];
              expected = [ ];
            };
          };
        };

        mkEntrypointScript = {
          type = lib.types.functionTo lib.types.package;
          description = ''
            Generate an entrypoint wrapper script from systemd service data.

            Takes an attrset `{ serviceData, pkgs }` where `serviceData`
            is the plain attrset produced by `extractServiceData`:
            `{ runtimeDirs, stateDirs, cacheDirs, logDirs, preStart, execStartPre, execStart, environment, ... }`

            The script:
            1. Creates runtime/state/cache/log directories
            2. Exports environment variables
            3. Runs preStart commands
            4. Runs ExecStartPre commands (respecting `-` prefix for ignore-failure)
            5. `exec`s the main process (ExecStart)
          '';
          file = "nix/lib/oci.nix";
          fn = pure.mkEntrypointScript;
        };

        mkEtcDerivation = {
          type = lib.types.functionTo lib.types.package;
          description = ''
            Create a derivation from a NixOS `environment.etc` entry.

            Takes `{ name, entry, pkgs }` where:
            - `name` is the etc path (e.g. "nsswitch.conf", "ssl/certs/ca-bundle.crt")
            - `entry` is the NixOS etc entry attrset with `.source` and optional `.mode`
            - `pkgs` is the package set

            Handles symlink modes by skipping chmod.
          '';
          file = "nix/lib/oci.nix";
          fn = pure.mkEtcDerivation;
        };
      };
    };
}
