# Runtime BDD test specs for performance.allocator.
#
# Verifies each allocator variant injects the expected `LD_PRELOAD=<store>/lib/<soName>`
# into `/proc/1/environ` inside a running container.
#
# Spec: openspec/changes/runtime-behavioral-test-coverage/specs/testing/runtime-behavior-verification/spec.md
#   Scenario: Allocator injects LD_PRELOAD
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      # Same allocator->soName mapping as nix/modules/_nixos-oci/performance/outputs.nix.
      # snmalloc is declared in that map but not present in the pinned nixpkgs;
      # its runtime scenario is intentionally skipped here to keep eval green
      # and will be added once snmalloc is available in the input.
      allocators = {
        jemalloc = {
          package = pkgs.jemalloc;
          soName = "libjemalloc.so";
        };
        mimalloc = {
          package = pkgs.mimalloc;
          soName = "libmimalloc.so";
        };
        tcmalloc = {
          package = pkgs.gperftools;
          soName = "libtcmalloc.so";
        };
      };

      mkAllocatorScenario =
        name: meta:
        let
          expected = "${meta.package}/lib/${meta.soName}";
        in
        {
          given = "a container with performance.allocator = \"${name}\"";
          "when" = "the process environment is read from /proc/1/environ";
          "then" = "LD_PRELOAD points at the ${name} shared library";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            entrypoint = [
              "${pkgs.busybox}/bin/busybox"
              "sh"
              "-c"
              "cat /proc/1/environ; sleep 3600"
            ];
            performance.enable = true;
            performance.allocator = name;
          };
          assertions.processEnv.LD_PRELOAD = expected;
        };
    in
    {
      test.oci.perContainer.performance-allocator-runtime = {
        runtime-jemalloc = mkAllocatorScenario "jemalloc" allocators.jemalloc;
        runtime-mimalloc = mkAllocatorScenario "mimalloc" allocators.mimalloc;
        runtime-tcmalloc = mkAllocatorScenario "tcmalloc" allocators.tcmalloc;
      };
    };
}
