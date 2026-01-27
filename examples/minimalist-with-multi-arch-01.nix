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
          minimalistWithMultiArch = {
            package = pkgs.hello;
            registry = "localhost:5000";
            tags = [
              "1.0.0"
              "latest"
            ];
            multiArch = {
              enabled = true;
              tempTagPrefix = "tmp";
            };
          };
        };
      };
  };
}
