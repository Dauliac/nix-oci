# Top-level test flake-module.
#
# Imported by the root flake's dev partition. Aggregates all test
# categories into perSystem.checks so `nix flake check` runs them.
#
# Hermetic checks (run via `nix flake check`):
#   checks.nix-unit            nix-lib unit tests (auto-generated)
#   checks.vm-deploy-*        NixOS VM integration tests
#   checks.oci-dive-*         Dive image analysis
#   checks.oci-dgoss-*        Dgoss hermetic tests
#   checks.lint-*             Formatting & prose linting
#   checks.build-*            Build validation
#   checks.treefmt            Formatting (from nix/treefmt.nix)
#
# Non-hermetic tests (need daemon/network) live in tests/e2e/
# and run via `task test:e2e`, NOT via `nix flake check`.
{
  imports = [
    ./unit/flake-module.nix
    ./vm/flake-module.nix
    ./lint/flake-module.nix
    ./build/flake-module.nix
  ];
}
