# CI multi-arch: each CI runner builds its native arch, then merge.
#
# Produces:
#   - `oci-push-tmp-<name>-<arch>` apps (one per runner)
#   - `oci-merge-<name>` app (creates manifest list)
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          ciMultiArch = {
            package = pkgs.hello;
            registry = "localhost:5000";
            tags = [
              "1.0.0"
              "latest"
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
