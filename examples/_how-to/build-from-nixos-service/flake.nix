# How-to: Build containers from NixOS services
#
# Test: nix build .#oci-my-nginx
#       nix run .#oci-copyToPodman-my-nginx
#       podman run --rm -p 8080:80 localhost/my-nginx:latest
#       curl http://localhost:8080
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-oci.url = "github:Dauliac/nix-oci";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nix-oci.modules.flake.nix-oci ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      oci.enabled = true;

      perSystem =
        { ... }:
        {
          oci.containers.my-nginx = {
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
    };
}
