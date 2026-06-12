# Shared type for policy runner registration.
#
# Each security/testing tool registers as a policy runner with a
# standardized interface. The gate collector uses this to:
#   - tier=pure   → build-time stamp derivation (parallel)
#   - tier=runtime → systemd oneshot in VM (podman needed)
#   - tier=network → systemd oneshot in VM (registry needed)
#
# Prefixed with _ so import-tree does not auto-import this as a module.
{ lib }:
let
  inherit (lib) mkOption types;
in
types.submodule {
  options = {
    enabled = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this policy runner is active.";
    };

    tier = mkOption {
      type = types.enum [
        "pure"
        "runtime"
        "network"
      ];
      description = ''
        Execution tier:
        - `"pure"` — Nix derivation, no podman, no network (conftest, dive, dockle, syft).
        - `"runtime"` — NixOS VM with podman, no external network (CST, dgoss, probes).
        - `"network"` — NixOS VM with localhost registry (push, sign, CVE scan).
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
      ];
      description = "Tool category for documentation and grouping.";
    };

    mkStamp = mkOption {
      type = types.nullOr (types.functionTo types.package);
      default = null;
      description = ''
        For tier=pure: function taking { archive, ociImage, containerId }
        and returning a stamp derivation (touch $out on success).
      '';
    };

    mkSystemdService = mkOption {
      type = types.nullOr (types.functionTo types.attrs);
      default = null;
      description = ''
        For tier=runtime|network: function returning a systemd service
        attrset for the NixOS test VM.
      '';
    };

    testOverrides = mkOption {
      type = types.submodule {
        options = {
          extraFlags = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Extra CLI flags injected only in test context.";
          };
          dbPath = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Pinned DB path (Nix store). Null = download fresh.";
          };
          registryUrl = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Override registry URL for test context (e.g. localhost:5000).";
          };
        };
      };
      default = { };
      description = "Test-only overrides (pinned DBs, extra flags, registry URL).";
    };
  };
}
