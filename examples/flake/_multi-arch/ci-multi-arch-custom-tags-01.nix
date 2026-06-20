# CI multi-arch with multiple tags.
#
# Shows that multi-arch works with the per-tag system: all tags
# get the multi-arch manifest after merge.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          ciMultiArchCustomTags = {
            package = pkgs.curl;
            registry = "ghcr.io/myorg";
            tags = [
              "1.0.0"
              "1.0"
              "1"
              "latest"
              "stable"
            ];
            multiArch.systems = [
              "x86_64-linux"
              "aarch64-linux"
            ];
          };
        };
      };
  };
}
