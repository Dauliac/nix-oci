# BDD test specs for hardening.apparmor option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-apparmor = {
        eval-defaults = {
          given = "a container with default hardening.apparmor";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
        };

        eval-with-hardening = {
          given = "a container with hardening enabled including apparmor";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with apparmor configured";
          level = "build";
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
