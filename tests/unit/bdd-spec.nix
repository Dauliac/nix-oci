# Unit test: verify the BDD test spec type accepts given/when/then fields.
#
# Run with:
#   nix eval --impure --expr 'import ./tests/unit/bdd-spec.nix {}'
_:
let
  flake = builtins.getFlake (toString ../..);
  pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
  lib = pkgs.lib;

  specType = import ../../nix/modules/oci/testing/_option-test-spec.nix { inherit lib; };

  # Evaluate a module that sets all BDD fields plus existing fields.
  evaluated = lib.evalModules {
    modules = [
      {
        options = {
          spec = lib.mkOption {
            type = specType;
            default = { };
          };
        };
      }
      {
        spec = {
          # BDD fields
          given = "a container with hardening enabled";
          "when" = "the seccomp profile is evaluated";
          "then" = "the profile restricts dangerous syscalls";
          target = "nixos-oci";
          # Existing fields
          level = "inspect";
          mode = "oneshot";
          default = { };
          override = { };
          exampleFile = null;
        };
      }
    ];
  };

  cfg = evaluated.config.spec;

  assertEqual =
    name: actual: expected:
    if actual == expected then
      true
    else
      throw "assertion '${name}' failed: expected ${builtins.toJSON expected}, got ${builtins.toJSON actual}";

  assertAll = [
    (assertEqual "given" cfg.given "a container with hardening enabled")
    (assertEqual "when" cfg."when" "the seccomp profile is evaluated")
    (assertEqual "then" cfg."then" "the profile restricts dangerous syscalls")
    (assertEqual "target" cfg.target "nixos-oci")
    (assertEqual "level" cfg.level "inspect")
    (assertEqual "mode" cfg.mode "oneshot")
    (assertEqual "exampleFile" cfg.exampleFile null)
  ];

  # Also verify defaults work (eval with empty config)
  defaultEval = lib.evalModules {
    modules = [
      {
        options = {
          spec = lib.mkOption {
            type = specType;
            default = { };
          };
        };
      }
    ];
  };

  defaultCfg = defaultEval.config.spec;

  defaultAsserts = [
    (assertEqual "default given" defaultCfg.given "")
    (assertEqual "default when" defaultCfg."when" "")
    (assertEqual "default then" defaultCfg."then" "")
    (assertEqual "default target" defaultCfg.target "oci")
    (assertEqual "default level" defaultCfg.level "eval")
    (assertEqual "default mode" defaultCfg.mode "oneshot")
    (assertEqual "default exampleFile" defaultCfg.exampleFile null)
  ];

  # Verify all target enum values are accepted
  targetTests =
    map
      (
        t:
        let
          e = lib.evalModules {
            modules = [
              {
                options.spec = lib.mkOption {
                  type = specType;
                  default = { };
                };
              }
              { spec.target = t; }
            ];
          };
        in
        assertEqual "target ${t}" e.config.spec.target t
      )
      [
        "oci"
        "nixos-oci"
        "home-manager-oci"
        "deploy-nixos"
        "deploy-home-manager"
      ];

  allPassed = builtins.all (x: x) (assertAll ++ defaultAsserts ++ targetTests);
in
if allPassed then
  "all ${
    builtins.toString (builtins.length (assertAll ++ defaultAsserts ++ targetTests))
  } BDD spec assertions passed"
else
  throw "unexpected: allPassed is false"
