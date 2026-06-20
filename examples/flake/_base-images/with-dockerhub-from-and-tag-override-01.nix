{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          withDockerHubFromAndTagOverride = {
            tag = "1.1.0";
            fromImage = {
              imageName = "library/alpine";
              imageTag = "3.21.2";
            };
          };
        };
      };
  };
}
