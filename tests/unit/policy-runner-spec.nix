/*
  Unit test for the policy-runner-spec type.

  Run with:
    nix eval --impure --expr 'import ./tests/unit/policy-runner-spec.nix {}'
*/
{ ... }:
let
  nixpkgs = builtins.getFlake "nixpkgs";
  lib = nixpkgs.lib;

  specModule = ../../nix/modules/oci/_testing/_policy-runner-spec.nix;

  # Helper: evaluate the spec module with given config and return config values.
  evalSpec =
    config:
    (lib.evalModules {
      modules = [
        specModule
        { inherit config; }
      ];
    }).config;

  # --- Test each tier value ---

  pureTier = evalSpec {
    enabled = true;
    tier = "pure";
    category = "policy";
  };

  runtimeTier = evalSpec {
    enabled = true;
    tier = "runtime";
    category = "cve";
  };

  networkTier = evalSpec {
    enabled = true;
    tier = "network";
    category = "signing";
  };

  # --- Test several category values ---

  lintCategory = evalSpec {
    enabled = false;
    tier = "pure";
    category = "lint";
  };

  complianceCategory = evalSpec {
    enabled = true;
    tier = "runtime";
    category = "compliance";
  };

  sbomCategory = evalSpec {
    enabled = true;
    tier = "pure";
    category = "sbom";
  };

  structureCategory = evalSpec {
    enabled = true;
    tier = "pure";
    category = "structure";
  };

  probeCategory = evalSpec {
    enabled = true;
    tier = "runtime";
    category = "probe";
  };

  licenseCategory = evalSpec {
    enabled = true;
    tier = "pure";
    category = "license";
  };

  pushCategory = evalSpec {
    enabled = true;
    tier = "network";
    category = "push";
  };

  # --- Test testOverrides submodule ---

  withOverrides = evalSpec {
    enabled = true;
    tier = "network";
    category = "cve";
    testOverrides = {
      extraFlags = [
        "--severity"
        "HIGH"
      ];
      dbPath = /tmp/test-db;
      registryUrl = "http://localhost:5000";
    };
  };

  # --- Test defaults ---

  withDefaults = evalSpec {
    tier = "pure";
    category = "policy";
  };

  # --- Assertions ---

  assertions =
    # Tier values
    assert pureTier.tier == "pure";
    assert runtimeTier.tier == "runtime";
    assert networkTier.tier == "network";
    # Category values
    assert pureTier.category == "policy";
    assert runtimeTier.category == "cve";
    assert networkTier.category == "signing";
    assert lintCategory.category == "lint";
    assert complianceCategory.category == "compliance";
    assert sbomCategory.category == "sbom";
    assert structureCategory.category == "structure";
    assert probeCategory.category == "probe";
    assert licenseCategory.category == "license";
    assert pushCategory.category == "push";
    # Enabled flag
    assert pureTier.enabled == true;
    assert lintCategory.enabled == false;
    # Defaults: enabled defaults to false, mkStamp/mkSystemdService default to null
    assert withDefaults.enabled == false;
    assert withDefaults.mkStamp == null;
    assert withDefaults.mkSystemdService == null;
    # testOverrides defaults
    assert withDefaults.testOverrides.extraFlags == [ ];
    assert withDefaults.testOverrides.dbPath == null;
    assert withDefaults.testOverrides.registryUrl == null;
    # testOverrides with values
    assert
      withOverrides.testOverrides.extraFlags == [
        "--severity"
        "HIGH"
      ];
    assert withOverrides.testOverrides.dbPath == /tmp/test-db;
    assert withOverrides.testOverrides.registryUrl == "http://localhost:5000";
    true;
in
{
  result = assertions;
  message = "All policy-runner-spec type assertions passed.";
}
