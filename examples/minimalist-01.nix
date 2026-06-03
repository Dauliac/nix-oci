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
          minimalist = {
            package = pkgs.kubectl;
          };
          minimalist2 = {
            package = pkgs.kubectl;
          };
        };
      };
  };
}
