# How-to: Share containers between flake-parts and NixOS deploy
#
# Test: nix build .#oci-my-app                          (flake-parts build)
#       nix build .#nixosConfigurations.server.config.system.build.toplevel  (NixOS deploy)
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-oci.url = "github:Dauliac/nix-oci";
  };

  outputs =
    inputs@{
      nixpkgs,
      nix-oci,
      ...
    }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ nix-oci.modules.flake.nix-oci ];
      systems = [ "x86_64-linux" ];
      oci.enabled = true;

      # Build-time: define the container for CI
      perSystem =
        { pkgs, ... }:
        {
          oci.containers.my-app = import ./container.nix { inherit pkgs; };
        };

      # Deploy-time: re-use the same container on NixOS
      flake.nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit nix-oci; };
        modules = [
          nix-oci.modules.nixos.nix-oci
          (
            { pkgs, ... }:
            {
              boot.isContainer = true;
              system.stateVersion = "25.11";

              oci = {
                enable = true;
                backend = "podman";
                # Same definition, plus deploy-specific options
                containers.my-app = (import ./container.nix { inherit pkgs; }) // {
                  autoStart = true;
                };
              };
            }
          )
        ];
      };
    };
}
