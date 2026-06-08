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
          minimalistWithDive = {
            package = pkgs.kubectl;
            test.dive.enabled = true;
          };
        };
      };
  };
}
