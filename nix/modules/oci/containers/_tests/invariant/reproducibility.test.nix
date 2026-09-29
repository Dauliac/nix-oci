# BDD test specs for reproducibility invariant (z83.7.1).
#
# Covers spec `Requirement: Reproducible image build` and its two
# scenarios (two builds -> same digest, label matches reality) per
# design D6.
#
# Uses the section-1 `manifestDigestMatches` typed assertion, which
# compares two manifest JSON files (typically the outputs of two
# independent `nix build` invocations that must produce the same
# sha256 digest for the invariant to hold).
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-reproducibility = {
        eval-defaults = {
          given = "a container with defaults and reproducibility label enabled";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and the reproducible label is present";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };

        inspect-reproducible-label = {
          given = "a container is built";
          "when" = "the OCI image is inspected";
          "then" = "the io.github.dauliac.nix-oci.build.reproducible label is present";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.build.reproducible" = "true";
          };
        };

        runtime-two-builds-same-digest = {
          given = "a container definition built twice in independent Nix invocations";
          "when" = "the manifest digest of each build is compared";
          "then" = "both builds yield the same SHA-256 digest";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
          # The harness materialises both manifests inside the VM at
          # the paths below (populated by the reproducibility fixture
          # in test-vm.nix). If the fixture is not yet wired in this
          # branch, the assertion is a no-op stub matched at spec
          # load time; once section-1's tmpfs staging and the two-run
          # fixture land, both paths are populated by the VM harness.
          assertions.manifestDigestMatches = {
            firstPath = "/var/lib/nix-oci-test/repro/first/manifest.json";
            secondPath = "/var/lib/nix-oci-test/repro/second/manifest.json";
          };
          stateDirectories = [ "/var/lib/nix-oci-test/repro" ];
        };
      };
    };
}
