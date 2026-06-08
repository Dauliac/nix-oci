{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          withDockerHubFromAndPackage = {
            package = pkgs.hello;
            fromImage = {
              imageName = "library/alpine";
              imageTag = "3.21.2";
            };
          };
        };
      };
  };
}
