# BDD test specs for stop-signal option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.stop-signal = {
        eval-defaults = {
          given = "a container with default stop signal";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };

        eval-custom-signal = {
          given = "a container with SIGQUIT stop signal";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with custom signal";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            stopSignal = "SIGQUIT";
          };
        };
      };
    };
}
