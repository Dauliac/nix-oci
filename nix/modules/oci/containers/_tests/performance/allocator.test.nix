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

        # TODO: re-enable as level = "runtime" when VM test infra supports
        # env inspection inside containers.
        build-jemalloc = {
          given = "a container with jemalloc allocator enabled";
          "when" = "the container image is built";
          "then" = "the image with jemalloc builds successfully";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            performance.enable = true;
            performance.allocator = "jemalloc";
          };
        };
      };
    };
}
