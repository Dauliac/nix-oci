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
          minimalistWithCredentialsLeaksTrivy = {
            package = pkgs.kubectl;
            credentialsLeak.trivy = {
              enabled = true;
            };
          };
        };
      };
  };
}
