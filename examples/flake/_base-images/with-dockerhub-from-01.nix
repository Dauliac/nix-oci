{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          withDockerHubFrom = {
            fromImage = {
              imageName = "library/alpine";
              imageTag = "3.21.2";
            };
          };
        };
      };
  };
}
