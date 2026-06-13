# BDD test specs for hardening.dns option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-dns = {
        eval-defaults = {
          given = "a container with default hardening.dns";
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
          given = "a container with hardening enabled including dns";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with dns configured";
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
