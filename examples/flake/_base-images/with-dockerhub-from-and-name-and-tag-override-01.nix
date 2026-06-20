{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          withDockerHubFromAndNameAndTagOverride = {
            name = "my-alpine";
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
