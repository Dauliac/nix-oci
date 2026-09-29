# BDD test specs for multi-arch emulated (QEMU binfmt) build path (opt-in).
#
# Covers task 8.3: verify that when the flake declares multiple systems and
# `multiArch.emulatedBuild.enable = true`, the per-arch outputs exist and
# each reports its own architecture in its manifest.
#
# LIMITATION: emulated builds require `boot.binfmt.emulatedSystems` on NixOS
# or QEMU user-mode registration on the host; without that, non-native
# builders will fail. These specs are therefore declared-only at eval level.
# Actual per-arch output realisation is intended to run under the opt-in
# `checks.<sys>.multi-arch` wired by task 8.4, where binfmt is assumed.
#
# NOTE (section-1 uplift): once section-1 typed assertions land, uplift the
# scenarios to assert per-arch OCI images (`_containers.<name>.archConfigs
# .<sys>._arch`) map to the expected OCI architecture strings and that the
# built manifests carry those values in `Config.Architecture`.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.multiArch-emulated = {
        eval-emulated-two-arch = {
          given = "a container with multiArch.systems = [x86_64-linux, aarch64-linux] and emulatedBuild.enable = true";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and both per-arch entries are populated";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            multiArch = {
              systems = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              emulatedBuild.enable = true;
            };
          };
        };

        eval-emulated-single-arch-degenerate = {
          # Guards that an emulated-build container with only the native arch
          # in `systems` still evaluates. This lets consumers stage into
          # multi-arch progressively without a flag flip.
          given = "emulatedBuild.enable = true with systems containing only the native arch";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            multiArch = {
              systems = [ "x86_64-linux" ];
              emulatedBuild.enable = true;
            };
          };
        };
      };
    };
}
