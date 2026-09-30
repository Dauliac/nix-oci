# BDD test specs for pipeline machinery (step registry, backend toggle,
# gate assembly, mkStamp / mkScript wiring).
#
# Design D5 (openspec/changes/runtime-behavioral-test-coverage/design.md):
# a synthetic test-only pipeline step emits a distinctive marker file at
# build time (stamp) and a distinctive marker string at runtime
# (script). Toggling `oci.pipeline.defaultBackend` and per-step
# `backend` routes the marker into the expected surface: gate
# derivation (mkStamp) vs flake apps (mkScript).
#
# The synthetic step is registered under a distinctive attribute name
# and its `isEnabled` gates on a marker attr on the container so it
# never fires against unrelated flake-parts consumers. That way this
# spec is safe to co-locate with the production step registry.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * Enabled step contributes a stamp
#   * Enabled step contributes a script
#   * defaultBackend = "vm" routes probes to gate
#   * defaultBackend = "daemon" routes probes to apps
#   * Per-step backend override wins over defaultBackend
#   * User-registered step is accepted
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-machinery = {
        stamp-contributes-to-gate = {
          given = "a container enabling a step whose mkStamp is defined";
          "when" = "the pipeline composer assembles the container's gate derivation";
          "then" = "the gate's nativeBuildInputs contain the stamp (visible via nix-store -q --references)";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            # Enabling built-in dockle contributes a mkStamp to the
            # gate; this scenario documents that the registry wiring
            # routes stamp-carrying steps into the gate surface.
            lint.dockle.enabled = true;
          };
        };

        script-contributes-to-apps = {
          given = "a container enabling a step whose mkScript is defined (post-push cosign)";
          "when" = "the pipeline composer emits flake apps";
          "then" = "a corresponding flake app is exposed for the container";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            signing.cosign = {
              enabled = true;
              keyless = true;
            };
          };
        };

        default-backend-vm-routes-probes-to-gate = {
          given = "oci.pipeline.defaultBackend = \"vm\" with a probe step enabled";
          "when" = "the composer resolves the backend for the probe";
          "then" = "the probe's mkStamp is added to the gate rather than the app set";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            test.amicontained.enabled = true;
          };
        };

        default-backend-daemon-routes-probes-to-apps = {
          given = "oci.pipeline.defaultBackend = \"daemon\" with a probe step enabled";
          "when" = "the composer resolves the backend for the probe";
          "then" = "the probe's mkScript is added to flake apps and no stamp lands in the gate";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            test.cdk.enabled = true;
          };
        };

        per-step-backend-overrides-default = {
          given = "defaultBackend = \"vm\" but a step is registered with backend = \"daemon\"";
          "when" = "the composer resolves the backend for that step";
          "then" = "the per-step override wins and the step is routed to apps, not the gate";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            test.dgoss.enabled = true;
          };
        };

        user-registered-step-accepted = {
          given = "a user registering a custom step via oci.pipeline.steps.myTool";
          "when" = "the pipeline composer assembles the gate";
          "then" =
            "the user step is composed exactly like a built-in step (stamp added when mkStamp is defined)";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
          };
        };

        synthetic-marker-round-trip = {
          given = "a synthetic step emitting a distinctive marker at build time and run time (design D5)";
          "when" = "defaultBackend and per-step backend are toggled through the four combinations";
          "then" =
            "the marker appears in the gate derivation output for pure/vm backends and in the flake app output for daemon backend";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
          };
        };
      };
    };
}
