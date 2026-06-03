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
          minimalistWithDgoss = {
            package = pkgs.kubectl;
            test.dgoss = {
              enabled = true;
              optionsPath = ./goss.yaml;
            };
          };
        };
      };
  };
}
