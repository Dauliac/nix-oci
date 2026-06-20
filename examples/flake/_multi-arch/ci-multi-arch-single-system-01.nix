# CI multi-arch with a single system.
#
# Useful when you want to use the multi-arch CI workflow (push-tmp + merge)
# but currently only target one architecture. Adding a second arch later
# is just adding a system string to the list.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          ciMultiArchSingleSystem = {
            package = pkgs.hello;
            registry = "localhost:5000";
            tags = [ "latest" ];
            multiArch.systems = [
              "x86_64-linux"
            ];
          };
        };
      };
  };
}
