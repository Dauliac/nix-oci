# How-to: Share containers between flake-parts and NixOS deploy
#
# Test: nix build .#oci-my-app                                              (flake-parts build)
#       nix build .#nixosConfigurations.server.config.system.build.toplevel (NixOS deploy)
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
      imports = [
        nix-oci.modules.flake.nix-oci
        # Container definition lives in ./module.nix so the repo's `tests/`
        # BDD suite can import the same module and verify the flake outputs.
        ./module.nix
      ];
      systems = [ "x86_64-linux" ];
      oci.enabled = true;

      flake.nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit nix-oci; };
        modules = [
          nix-oci.modules.nixos.nix-oci
          ./nixos-server.nix
        ];
      };
    };
}
