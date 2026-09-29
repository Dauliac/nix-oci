# BDD test specs for multi-arch cross-compile path (opt-in).
#
# Covers task 8.2: verify that a container declared for a foreign architecture
# via `multiArch.crossBuild.enable = true` builds via pkgsCross and produces
# a manifest reporting the foreign architecture (arm64 for aarch64-linux).
#
# LIMITATION: full runtime verification of the resulting manifest's
# `architecture` field requires either a remote aarch64 builder or QEMU
# binfmt on the CI runner. Standard `nix build` on an x86_64 host without a
# remote builder cannot realise a pkgsCross derivation for every dependency
# graph. These specs are therefore declared-only at eval level: they assert
# that the option surface accepts the cross-build configuration and the
# per-arch package inference picks the pkgsCross path. Actual manifest
# inspection is intended to run under the opt-in `checks.<sys>.multi-arch`
# wired by task 8.4, where a remote builder or binfmt is assumed present.
#
# NOTE (section-1 uplift): once the new typed assertion vocabulary from
# section 1 lands (specifically `manifestDigestMatches`-style checks against
# `Config.Architecture`), the build-level scenario should be uplifted to
# call `imageInspect.Architecture == "arm64"` directly against the built OCI
# image. Until then, we keep this as eval-only to avoid the missing-builder
# failure mode.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.multiArch-crossCompile = {
        eval-cross-compile-aarch64-from-x86_64 = {
          given = "an x86_64 host and a container with multiArch.crossBuild.enable = true targeting aarch64-linux";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and the aarch64 archConfig is populated";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            multiArch = {
              systems = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              crossBuild.enable = true;
            };
          };
        };

        eval-cross-build-and-emulated-are-mutually-exclusive = {
          # The multiArch spec documents crossBuild and emulatedBuild as
          # mutually exclusive; this scenario guards the happy-path where
          # only crossBuild is enabled and the module accepts the config.
          given = "crossBuild.enable = true and emulatedBuild.enable = false";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            multiArch = {
              systems = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              crossBuild.enable = true;
              emulatedBuild.enable = false;
            };
          };
        };
      };
    };
}
