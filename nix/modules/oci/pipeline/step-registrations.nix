# Register all built-in tools as pipeline steps.
#
# Replaces policy-runner-registrations.nix with richer step specs
# that include phase, deps, command, backend, timeout.
#
# Pure tools → build-time gate (mkStamp)
# Probes → vm or daemon (mkStamp + mkScript)
# Post-push → daemon only (mkScript)
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
      oci.pipeline.steps = {
        # ── Phase: build-check (pure Nix derivations) ──────────

        conftest = {
          phase = "build-check";
          category = "policy";
          backend = "pure";
          isEnabled = c: c.policy.conftest.enabled or true;
          mkStamp =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkCheckPolicyConftest {
              inherit perSystemConfig containerId;
            };
        };

        dockle = {
          phase = "build-check";
          category = "lint";
          backend = "pure";
          isEnabled = c: c.test.dockle.enabled or true;
          mkStamp =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkCheckLintDockle {
              inherit perSystemConfig containerId;
            };
        };

        dive = {
          phase = "build-check";
          category = "structure";
          backend = "pure";
          isEnabled = c: c.test.dive.enabled or true;
          mkStamp =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkCheckDive {
              inherit perSystemConfig containerId;
            };
        };

        sbom-syft = {
          phase = "build-check";
          category = "sbom";
          backend = "pure";
          isEnabled = c: c.sbom.syft.enabled or true;
          mkStamp =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkCheckSBOMSyft {
              inherit perSystemConfig containerId;
            };
        };

        credentials-leak = {
          phase = "build-check";
          category = "credentials";
          backend = "pure";
          isEnabled = c: c.credentialsLeak.trivy.enabled or true;
          mkStamp =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkCheckCredentialsLeakTrivy {
              inherit perSystemConfig containerId;
            };
        };

        license-conftest = {
          phase = "build-check";
          category = "license";
          backend = "pure";
          isEnabled = c: c.license.conftest.enabled or false;
          mkStamp = null;
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptLicenseConftest {
              inherit perSystemConfig containerId;
            };
        };

        # ── Phase: probe (backend-toggled: vm or daemon) ───────

        amicontained = {
          phase = "probe";
          category = "probe";
          label = "probe:amicontained";
          deps = [ "load-image" ];
          isEnabled = c: c.test.amicontained.enabled or false;
          mkStamp =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkCheckAmicontained {
              inherit perSystemConfig containerId;
            };
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptAmicontained {
              inherit perSystemConfig containerId;
            };
        };

        cdk = {
          phase = "probe";
          category = "probe";
          label = "probe:cdk";
          deps = [ "load-image" ];
          isEnabled = c: c.test.cdk.enabled or false;
          mkStamp =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkCheckCdk {
              inherit perSystemConfig containerId;
            };
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptCdk {
              inherit perSystemConfig containerId;
            };
        };

        deepce = {
          phase = "probe";
          category = "probe";
          label = "probe:deepce";
          deps = [ "load-image" ];
          isEnabled = c: c.test.deepce.enabled or false;
          mkStamp =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkCheckDeepce {
              inherit perSystemConfig containerId;
            };
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptDeepce {
              inherit perSystemConfig containerId;
            };
        };

        linpeas = {
          phase = "probe";
          category = "probe";
          label = "probe:linpeas";
          deps = [ "load-image" ];
          isEnabled = c: c.test.linpeas.enabled or false;
          mkStamp =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkCheckLinpeas {
              inherit perSystemConfig containerId;
            };
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptLinpeas {
              inherit perSystemConfig containerId;
            };
        };

        cst = {
          phase = "probe";
          category = "structure";
          label = "probe:cst";
          deps = [ "load-image" ];
          isEnabled = c: c.test.containerStructureTest.enabled or false;
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptContainerStructureTest {
              inherit perSystemConfig containerId;
            };
        };

        dgoss = {
          phase = "probe";
          category = "structure";
          label = "probe:dgoss";
          deps = [ "load-image" ];
          isEnabled = c: c.test.dgoss.enabled or false;
          # mkStamp omitted: dgoss lib.nix references a non-existent
          # optionsPath option. mkCheckDgoss is broken upstream.
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptDgoss {
              inherit perSystemConfig containerId;
            };
        };

        # ── Phase: post-push (daemon only, needs registry) ─────

        # ── Phase: pre-push (impure, blocks push if failing) ────
        # CVE/compliance scanners run on the local archive before push.
        # They download fresh DBs (impure) so they can't be in the pure gate.

        cve-trivy = {
          phase = "pre-push";
          category = "cve";
          isEnabled = c: c.cve.trivy.enabled or false;
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptCVETrivy {
              inherit perSystemConfig containerId;
            };
          timeout = 300;
        };

        cve-grype = {
          phase = "pre-push";
          category = "cve";
          isEnabled = c: c.cve.grype.enabled or false;
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptCVEGrype {
              inherit perSystemConfig containerId;
            };
          timeout = 300;
        };

        cve-vulnix = {
          phase = "pre-push";
          category = "cve";
          isEnabled = c: c.cve.vulnix.enabled or false;
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptCVEVulnix {
              inherit perSystemConfig containerId;
            };
          timeout = 300;
        };

        compliance-trivy = {
          phase = "pre-push";
          category = "compliance";
          isEnabled = c: c.compliance.trivy.enabled or false;
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptComplianceTrivy {
              inherit perSystemConfig containerId;
            };
        };

        cosign-sign = {
          phase = "post-push";
          category = "signing";
          deps = [ "push" ];
          isEnabled = c: c.signing.cosign.enabled or false;
          mkScript =
            {
              containerId,
              perSystemConfig,
            }:
            ociLib.mkScriptSignCosign {
              inherit perSystemConfig containerId;
            };
          timeout = 60;
        };
      };
    };
}
