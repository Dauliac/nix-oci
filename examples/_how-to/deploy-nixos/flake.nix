# How-to: Deploy containers on NixOS
#
# Test: nix build .#nixosConfigurations.my-server.config.system.build.toplevel
#       (or deploy to a real/VM NixOS system)
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-oci.url = "github:Dauliac/nix-oci";
  };

  outputs =
    { nixpkgs, nix-oci, ... }:
    {
      nixosConfigurations.my-server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit nix-oci; };
        modules = [
          nix-oci.modules.nixos.nix-oci
          (
            { pkgs, ... }:
            {
              # Minimal NixOS config for testing
              boot.isContainer = true;
              system.stateVersion = "25.11";

              oci = {
                enable = true;
                backend = "podman";

                containers.my-webserver = {
                  package = pkgs.python3Minimal;
                  dependencies = with pkgs; [
                    bashInteractive
                    coreutils
                  ];
                  entrypoint = [
                    "${pkgs.writeShellScript "serve" ''
                      mkdir -p /tmp/www
                      echo "Hello from nix-oci" > /tmp/www/index.html
                      cd /tmp/www
                      exec python3 -m http.server 8080
                    ''}"
                  ];
                  autoStart = true;
                  ports = [ "8080:8080" ];
                };
              };
            }
          )
        ];
      };
    };
}
