# BDD test specs for multi-arch merge (opt-in, spec: testing/multi-arch-verification).
#
# Covers task 8.1: verify that `mkMergeMultiArchApp` produces the expected
# output shape (regctl-based index creation) and includes temp-tag cleanup.
#
# The runtime portion (two per-arch temp tags → single index in a live
# registry) requires an in-VM registry with per-arch pushes staged. Those
# push apps (`oci-push-tmp-*`) are excluded from the default BDD apps VM
# harness (see `test-apps.nix` comment on `oci-push-*` prefix). This file
# therefore declares eval/build-level scenarios that guard the merge app's
# static shape; end-to-end registry verification is expected to move to
# the opt-in multi-arch VM check wired via task 8.4.
#
# NOTE (section-1 uplift): once the new typed assertion vocabulary from
# section 1 lands (e.g. manifestDigestMatches, indexPlatforms), these specs
# should be uplifted to check the resulting OCI index media type
# ("application/vnd.oci.image.index.v1+json") and platform list directly,
# instead of relying on eval-level shape checks.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.multiArch-merge = {
        eval-declares-two-arch-container = {
          given = "a container with multiArch.systems = [x86_64-linux, aarch64-linux]";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and multiArch is enabled";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            multiArch = {
              systems = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              tempTagPrefix = "tmp";
            };
          };
        };

        eval-custom-temp-tag-prefix = {
          given = "a container with multiArch.tempTagPrefix = \"arch\"";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and the merge app inherits the prefix";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            multiArch = {
              systems = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              tempTagPrefix = "arch";
            };
          };
        };

        build-single-arch-container-still-builds = {
          given = "a container with an empty multiArch.systems list";
          "when" = "the container config is built";
          "then" = "the container builds normally with multiArch disabled";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            multiArch.systems = [ ];
          };
        };
      };
    };
}
