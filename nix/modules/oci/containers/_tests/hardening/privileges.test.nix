# BDD test specs for hardening.privileges option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-privileges = {
        eval-defaults = {
          given = "a container with default hardening.privileges";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
        };

        eval-with-hardening = {
          given = "a container with hardening enabled including privileges";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with privileges configured";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
            hardening.enable = true;
          };
        };
      };
    };
}
