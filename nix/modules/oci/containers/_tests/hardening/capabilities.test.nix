# BDD test specs for hardening.capabilities option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-capabilities = {
        eval-defaults = {
          given = "a container with default hardening.capabilities";
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
          given = "a container with hardening enabled including capabilities";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with capabilities configured";
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
