# BDD test specs for auto-labels option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.auto-labels = {
        eval-defaults = {
          given = "a container with auto-labels enabled (default)";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and auto-labels are generated";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };

        eval-disabled = {
          given = "a container with auto-labels disabled";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds without auto-labels";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            autoLabels = false;
          };
        };
      };
    };
}
