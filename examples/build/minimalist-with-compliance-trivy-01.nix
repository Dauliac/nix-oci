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
          minimalistWithComplianceTrivy = {
            package = pkgs.kubectl;
            compliance.trivy = {
              enabled = true;
            };
          };
        };
      };
  };
}
