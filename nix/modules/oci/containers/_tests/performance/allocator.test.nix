# BDD test specs for performance.allocator option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-allocator = {
        eval-defaults = {
          given = "a container with default performance.allocator";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };

        runtime-jemalloc-injected = {
          given = "a container with jemalloc allocator enabled";
          "when" = "the container environment is inspected at runtime";
          "then" = "LD_PRELOAD contains libjemalloc";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            performance.enable = true;
            performance.allocator = "jemalloc";
            entrypoint = [ "${pkgs.busybox}/bin/busybox" ];
          };
          testDependencies = [ pkgs.busybox ];
          assertions.succeeds = [
            {
              command = "${pkgs.busybox}/bin/busybox";
              args = "env";
              stdout = "libjemalloc";
            }
          ];
        };
      };
    };
}
