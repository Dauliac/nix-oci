# BDD test specs for initialize-nix-database option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.initialize-nix-database = {
        eval-defaults = {
          given = "a container with default nix database settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        eval-enabled = {
          given = "a container with nix database initialization enabled";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with nix database configured";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            initializeNixDatabase = true;
          };
        };
      };
    };
}
