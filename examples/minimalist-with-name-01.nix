{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithName = {
            name = "hola";
            package = pkgs.hello;
          };
        };
      };
  };
}
