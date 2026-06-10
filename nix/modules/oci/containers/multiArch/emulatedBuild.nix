# Container multiArch.emulatedBuild options
#
# When enabled, non-native architectures are built via QEMU binfmt emulation
# instead of Nix cross-compilation (pkgsCross). This is slower but far more
# compatible -- every package that builds natively for the target arch will work.
#
# Prerequisites:
#   - NixOS: `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`
#   - Non-NixOS: register QEMU binfmt handlers manually or via `qemu-user-static`
#   - nix.conf: `extra-platforms = aarch64-linux` (NixOS sets this automatically)
#
# Mutually exclusive with `multiArch.crossBuild.enable`.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.multiArch.emulatedBuild = {
            enable = mkOption {
              type = types.bool;
              description = ''
                Enable QEMU binfmt emulated builds for multi-arch images.

                When true, non-native architectures listed in `multiArch.systems`
                are built by importing nixpkgs for the target system and relying on
                QEMU user-mode emulation (binfmt_misc) to execute the foreign builders.

                This is slower than native cross-compilation (`crossBuild.enable`)
                but works for any package that builds natively on the target platform,
                including packages that lack proper cross-compilation support.

                Prerequisites:
                - On NixOS: `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`
                - On other distros: register QEMU binfmt handlers (e.g. `qemu-user-static`)
                - In nix.conf: `extra-platforms = aarch64-linux` (NixOS sets this automatically)

                Mutually exclusive with `multiArch.crossBuild.enable`.
              '';
              default = false;
            };
          };
        };
    };
}
