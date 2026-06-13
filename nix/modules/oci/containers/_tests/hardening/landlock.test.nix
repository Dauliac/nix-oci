# BDD test specs for hardening.landlock option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-landlock = {
        eval-defaults = {
          given = "a container with default hardening.landlock";
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
          given = "a container with hardening enabled including landlock";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with landlock configured";
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
