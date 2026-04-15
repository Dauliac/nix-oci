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
          minimalist-with-install-nix = {
            package = pkgs.kubectl;
            installNix = true;
          };
        };
      };
  };
}
