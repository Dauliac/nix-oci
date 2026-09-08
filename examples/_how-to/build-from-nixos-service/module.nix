# Flake-parts module extracted from ./flake.nix so both the standalone
# how-to flake AND the repo's `tests/` BDD suite can consume the same
# container definition — keeping the docs' `nix run` commands honest.
{ ... }:
{
  config.perSystem =
    { ... }:
    {
      config.oci.containers.my-nginx = {
        mainService = "nginx";
        nixosConfig.modules = [
          (
            { pkgs, ... }:
            {
              services.nginx = {
                enable = true;
                virtualHosts.localhost = {
                  locations."/".return = "200 'Hello from nix-oci!'";
                };
              };
              environment.systemPackages = [ pkgs.curl ];
            }
          )
        ];
      };
    };
}
