{ ... }:
{
  config = {
    perSystem =
      {
        pkgs,
        config,
        ...
      }:
      {
        config.oci.containers = {
          minimalistWithDebug = {
            package = pkgs.kubectl;
            debug = {
              enabled = true;
              entrypoint = {
                enabled = true;
              };
            };
          };
        };
      };
  };
}
