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
          minimalistWithContainerStructureTest = {
            package = pkgs.kubectl;
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./test.yaml
              ];
            };
          };
        };
      };
  };
}
