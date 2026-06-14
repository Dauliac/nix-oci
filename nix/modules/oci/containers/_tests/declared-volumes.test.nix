# BDD test specs for declared-volumes option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.declared-volumes = {
        eval-defaults = {
          given = "a container with no declared volumes";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };

        eval-with-volumes = {
          given = "a container with declared volumes";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with volumes configured";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            declaredVolumes = [
              "/data"
              "/config"
            ];
          };
        };
      };
    };
}
