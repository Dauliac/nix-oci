# Runtime BDD test specs for performance.glibcTunables{,Preset}.
#
# Verifies explicit and preset-expanded glibc tunables reach the container
# init process environment as GLIBC_TUNABLES=<colon-joined key=value list>.
#
# effectiveTunables = presetTunables // hugepageTunables // cfg.glibcTunables;
# tunablesStr       = concatStringsSep ":" mapAttrsToList (n: v: "${n}=${v}");
# Attribute-set iteration is lexicographic on the key.
#
# Spec: openspec/changes/runtime-behavioral-test-coverage/specs/testing/runtime-behavior-verification/spec.md
#   Scenario: glibc tunables preset expands into env
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
      test.oci.perContainer.performance-glibc-tunables-runtime = {
        # Explicit tunables only: two keys sorted lexicographically.
        # glibc.malloc.arena_max=2 sorts before glibc.malloc.tcache_count=7.
        runtime-explicit-tunables = {
          given = "a container with two explicit glibcTunables entries";
          "when" = "the process environment is read inside the container";
          "then" = "GLIBC_TUNABLES contains the colon-joined key=value pairs in key order";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            entrypoint = readInit;
            performance.enable = true;
            performance.glibcTunables = {
              "glibc.malloc.arena_max" = "2";
              "glibc.malloc.tcache_count" = "7";
            };
          };
          assertions.processEnv.GLIBC_TUNABLES = "glibc.malloc.arena_max=2:glibc.malloc.tcache_count=7";
        };

        # Preset "high-throughput" expansion.
        # presetMap."high-throughput" = {
        #   "glibc.malloc.arena_max" = "8";
        #   "glibc.malloc.tcache_count" = "15";
        #   "glibc.malloc.mxfast" = "256";
        # }
        # Lexicographic order: arena_max, mxfast, tcache_count.
        runtime-preset-high-throughput = {
          given = "a container with glibcTunablesPreset = \"high-throughput\"";
          "when" = "the process environment is read inside the container";
          "then" = "GLIBC_TUNABLES equals the preset expansion in key order";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            entrypoint = readInit;
            performance.enable = true;
            performance.glibcTunablesPreset = "high-throughput";
          };
          assertions.processEnv.GLIBC_TUNABLES = "glibc.malloc.arena_max=8:glibc.malloc.mxfast=256:glibc.malloc.tcache_count=15";
        };

        # Explicit tunables override preset values (right side of //).
        # preset "balanced" arena_max=4 overridden by explicit arena_max=16.
        runtime-explicit-overrides-preset = {
          given = "a container where an explicit glibcTunables key overrides its preset value";
          "when" = "the process environment is read inside the container";
          "then" = "GLIBC_TUNABLES shows the explicit value, not the preset value";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            entrypoint = readInit;
            performance.enable = true;
            performance.glibcTunablesPreset = "balanced";
            performance.glibcTunables = {
              "glibc.malloc.arena_max" = "16";
            };
          };
          # balanced expands to arena_max=4, mmap_threshold=131072, tcache_count=7, trim_threshold=131072
          # Explicit arena_max=16 overrides -> final keys: arena_max=16, mmap_threshold=131072, tcache_count=7, trim_threshold=131072
          assertions.processEnv.GLIBC_TUNABLES = "glibc.malloc.arena_max=16:glibc.malloc.mmap_threshold=131072:glibc.malloc.tcache_count=7:glibc.malloc.trim_threshold=131072";
        };
      };
    };
}
