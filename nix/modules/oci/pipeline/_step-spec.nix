# Pipeline step specification type.
#
# Each security/testing/delivery tool registers as a pipeline step.
# The pipeline composer reads all steps and generates:
#   - Gate derivation (pure + vm steps, build-time)
#   - Taskfile JSON (daemon + network steps, runtime)
#
# Prefixed with _ so import-tree does not auto-import this as a module.
{ lib }:
let
  inherit (lib) mkOption types;
in
types.submodule {
  options = {
    phase = mkOption {
      type = types.enum [
        "build-check"
        "probe"
        "pre-push"
        "post-push"
      ];
      description = ''
        Pipeline phase:
        - `"build-check"` — pure Nix derivation, no runtime needed (conftest, dockle, dive, sbom).
        - `"probe"` — container introspection (amicontained, cdk, deepce, linpeas, cst, dgoss).
        - `"pre-push"` — runs before push (load-image).
        - `"post-push"` — runs after push (signing, compliance scans).
      '';
    };

    category = mkOption {
      type = types.enum [
        "policy"
        "cve"
        "lint"
        "compliance"
        "sbom"
        "signing"
        "structure"
        "probe"
        "license"
        "push"
        "credentials"
      ];
      description = "Tool category for documentation and grouping.";
    };

    backend = mkOption {
      type = types.nullOr (
        types.enum [
          "pure"
          "vm"
          "daemon"
        ]
      );
      default = null;
      description = ''
        Execution backend override. When null, inferred from phase:
        - build-check → pure
        - probe → global oci.pipeline.defaultBackend
        - pre-push/post-push → daemon
      '';
    };

    deps = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Step names this step depends on (DAG ordering for Taskfile).";
    };

    isEnabled = mkOption {
      type = types.functionTo types.bool;
      description = ''
        Function `containerConfig → bool` that determines whether this
        step is active for a given container.
      '';
    };

    mkStamp = mkOption {
      type = types.nullOr (types.functionTo types.package);
      default = null;
      description = ''
        For pure/vm backend: function `{ containerId, perSystemConfig } → derivation`.
        The derivation is a stamp (touch $out on success).
        Added to the gate's nativeBuildInputs.
      '';
    };

    mkScript = mkOption {
      type = types.nullOr (types.functionTo types.package);
      default = null;
      description = ''
        For daemon backend: function `{ containerId, perSystemConfig } → package`.
        The package is a writeShellApplication added to the Taskfile.
      '';
    };

    timeout = mkOption {
      type = types.int;
      default = 120;
      description = "Timeout in seconds for this step (Taskfile `timeout` field).";
    };

    parallel = mkOption {
      type = types.bool;
      default = true;
      description = "Whether this step can run concurrently with siblings in the same phase.";
    };

    label = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Custom output prefix for Taskfile (e.g. `probe:cdk` instead of `probe-cdk`).";
    };
  };
}
