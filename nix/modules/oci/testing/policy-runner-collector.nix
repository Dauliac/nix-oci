# Collects policy runner registrations from tool lib.nix files.
#
# Each security/testing tool registers itself via
# config.perSystem.oci.internal.policyRunners.<name>.
# The gate (gate.nix) consumes this to build the policy gate.
{
  lib,
  flake-parts-lib,
  ...
}:
let
  policyRunnerType = import ./_policy-runner-spec.nix { inherit lib; };
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { ... }:
    {
      options.oci.internal.policyRunners = lib.mkOption {
        type = lib.types.attrsOf policyRunnerType;
        default = { };
        internal = true;
        description = ''
          Registry of policy runners contributed by tool lib.nix files.

          Each runner has: enabled, tier (pure/runtime/network), category,
          mkStamp (for pure tier), mkSystemdService (for runtime/network).
          The gate collector uses this to build the build-time policy gate.
        '';
      };
    }
  );
}
