# Test infrastructure flake module.
#
# The test modules (test-collector, test-check-eval, etc.) are already
# imported by the main nix-oci module via import-tree. This module is
# a marker that enables test-specific behavior — consumers import it
# alongside the main module to signal "I want test infrastructure".
#
# Currently a no-op since all test modules are auto-discovered.
# Will be used for test-specific configuration in the future.
_inputs: { }
