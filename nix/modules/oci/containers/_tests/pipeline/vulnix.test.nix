# BDD test specs for the vulnix pipeline step.
#
# vulnix runs in the pre-push phase and inspects the Nix closure of the
# built image (unlike trivy/grype which walk archive layers). Enabling
# it wires an `oci-cve-vulnix-<container>` script that emits a summary
# referencing store paths.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * vulnix CVE scanner runs on Nix closure
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-vulnix = {
        eval-defaults = {
          given = "a container with default cve.vulnix settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-vulnix-enabled = {
          given = "a container with cve.vulnix.enabled = true";
          "when" = "the pipeline composer wires the pre-push vulnix step";
          "then" = "the container package builds and exposes the vulnix script";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            cve.vulnix.enabled = true;
          };
        };

        build-vulnix-summary = {
          given = "a container with vulnix enabled";
          "when" = "the vulnix app runs against the Nix closure";
          "then" = "the emitted summary references store paths of the closure";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = false;
            cve.vulnix.enabled = true;
          };
        };
      };
    };
}
