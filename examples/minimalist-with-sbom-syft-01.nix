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
          minimalistWithSyft = {
            package = pkgs.kubectl;
            sbom.syft = {
              enabled = true;
              # config = {
              #   enabled = true;
              #   path = ./minimalist-with-sbom-syft-01.yaml;
              # };
            };
          };
        };
      };
  };
}
