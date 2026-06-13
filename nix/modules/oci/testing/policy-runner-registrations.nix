# Register all existing security/testing tools as policy runners.
#
# This module bridges the existing tool lib.nix functions to the
# unified policy runner interface. Each tool's mkCheck* function
# becomes the mkStamp for its policy runner registration.
#
# Pure tools (tier=pure): run as Nix derivations, build-time gate
# Runtime tools (tier=runtime): need podman in VM
# Network tools (tier=network): need localhost registry in VM
{
  lib,
  flake-parts-lib,
  ...
}:
{
  config.perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
      hasOciLib = ociLib != { };
    in
    lib.mkIf hasOciLib {
      oci.internal.policyRunners = {
        # ── Tier: pure (build-time, no podman) ────────────────

        conftest = {
          enabled = true;
          tier = "pure";
          category = "policy";
          mkStamp =
            { containerId, ... }:
            ociLib.mkCheckPolicyConftest {
              perSystemConfig = config.oci;
              globalConfig = { };
              inherit containerId;
            };
        };

        dockle = {
          enabled = true;
          tier = "pure";
          category = "lint";
          mkStamp =
            { containerId, ... }:
            ociLib.mkCheckLintDockle {
              perSystemConfig = config.oci;
              globalConfig = { };
              inherit containerId;
            };
        };

        dive = {
          enabled = true;
          tier = "pure";
          category = "structure";
          mkStamp =
            { containerId, ... }:
            ociLib.mkCheckDive {
              perSystemConfig = config.oci;
              inherit containerId;
            };
        };

        syft = {
          enabled = true;
          tier = "pure";
          category = "sbom";
          mkStamp =
            { containerId, ... }:
            ociLib.mkCheckSBOMSyft {
              perSystemConfig = config.oci;
              globalConfig = { };
              inherit containerId;
            };
        };

        credentials-leak = {
          enabled = true;
          tier = "pure";
          category = "compliance";
          mkStamp =
            { containerId, ... }:
            ociLib.mkCheckCredentialsLeakTrivy {
              perSystemConfig = config.oci;
              globalConfig = { };
              inherit containerId;
            };
        };

        # ── Tier: runtime (needs podman in VM) ────────────────

        cst = {
          enabled = true;
          tier = "runtime";
          category = "structure";
        };

        dgoss = {
          enabled = true;
          tier = "runtime";
          category = "structure";
        };

        amicontained = {
          enabled = true;
          tier = "runtime";
          category = "probe";
        };

        cdk = {
          enabled = true;
          tier = "runtime";
          category = "probe";
        };

        deepce = {
          enabled = true;
          tier = "runtime";
          category = "probe";
        };

        linpeas = {
          enabled = true;
          tier = "runtime";
          category = "probe";
        };

        # ── Tier: network (needs localhost registry in VM) ────

        trivy-cve = {
          enabled = true;
          tier = "network";
          category = "cve";
          testOverrides.extraFlags = [
            "--skip-db-update"
            "--offline-scan"
          ];
        };

        grype = {
          enabled = true;
          tier = "network";
          category = "cve";
          testOverrides.extraFlags = [
            "--db-auto-update=false"
          ];
        };

        cosign = {
          enabled = true;
          tier = "network";
          category = "signing";
        };

        trivy-compliance = {
          enabled = true;
          tier = "network";
          category = "compliance";
        };

        license-conftest = {
          enabled = true;
          tier = "pure";
          category = "license";
        };
      };
    };
}
