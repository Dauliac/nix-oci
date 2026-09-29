# Runtime BDD test specs for performance.allocatorConfig.
#
# Verifies allocator-specific tunable env vars materialise in the
# container init process environment:
#   - jemalloc  -> MALLOC_CONF (comma-joined key:value, defaults merged)
#   - mimalloc  -> MIMALLOC_<KEY> (one env per key)
#   - tcmalloc  -> TCMALLOC_<KEY> (one env per key)
#   - snmalloc  -> no runtime tunables (out of scope)
#
# Spec: openspec/changes/runtime-behavioral-test-coverage/specs/testing/runtime-behavior-verification/spec.md
#   Scenario: Allocator-specific tunable env vars appear
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      readInit = [
        "${pkgs.busybox}/bin/busybox"
        "sh"
        "-c"
        "cat /proc/1/environ; sleep 3600"
      ];
    in
    {
      test.oci.perContainer.performance-allocator-config-runtime = {
        # jemalloc: MALLOC_CONF is jemallocDefaults // user-config, joined "k:v"
        # by "," in lexicographic key order.
        # jemallocDefaults = { abort_conf = "true"; background_thread = "true"; muzzy_decay_ms = "0"; }
        # user-config     = { narenas = "4"; }
        # -> "abort_conf:true,background_thread:true,muzzy_decay_ms:0,narenas:4"
        runtime-jemalloc-malloc-conf = {
          given = "a jemalloc container with allocatorConfig.narenas = 4";
          "when" = "the process environment is read inside the container";
          "then" = "MALLOC_CONF contains narenas:4 alongside jemalloc container-safety defaults";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            entrypoint = readInit;
            performance.enable = true;
            performance.allocator = "jemalloc";
            performance.allocatorConfig = {
              narenas = "4";
            };
          };
          assertions.processEnv.MALLOC_CONF = "abort_conf:true,background_thread:true,muzzy_decay_ms:0,narenas:4";
        };

        # mimalloc: one MIMALLOC_<KEY> env var per config entry.
        runtime-mimalloc-per-key-env = {
          given = "a mimalloc container with allocatorConfig.SHOW_STATS = 1";
          "when" = "the process environment is read inside the container";
          "then" = "MIMALLOC_SHOW_STATS = 1 is present in the init environment";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            entrypoint = readInit;
            performance.enable = true;
            performance.allocator = "mimalloc";
            performance.allocatorConfig = {
              SHOW_STATS = "1";
            };
          };
          assertions.processEnv.MIMALLOC_SHOW_STATS = "1";
        };

        # tcmalloc: one TCMALLOC_<KEY> env var per config entry.
        runtime-tcmalloc-per-key-env = {
          given = "a tcmalloc container with allocatorConfig.SAMPLE_PARAMETER = 524288";
          "when" = "the process environment is read inside the container";
          "then" = "TCMALLOC_SAMPLE_PARAMETER = 524288 is present in the init environment";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            entrypoint = readInit;
            performance.enable = true;
            performance.allocator = "tcmalloc";
            performance.allocatorConfig = {
              SAMPLE_PARAMETER = "524288";
            };
          };
          assertions.processEnv.TCMALLOC_SAMPLE_PARAMETER = "524288";
        };
      };
    };
}
