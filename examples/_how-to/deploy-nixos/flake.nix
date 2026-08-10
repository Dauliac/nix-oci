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
    {
      nixpkgs,
      nix-oci,
      ...
    }:
    {
      nixosConfigurations.my-server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit nix-oci; };
        modules = [
          nix-oci.modules.nixos.nix-oci
          # NixOS-side wiring lives in ./nixos-module.nix so tests can
          # instantiate the same module against local nix-oci.
          ./nixos-module.nix
        ];
      };
    };
}
