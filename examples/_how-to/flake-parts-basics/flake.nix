# How-to: Build and run with flake-parts
#
# Test: nix build .#oci-hello
#       nix run .#oci-copyToPodman-hello
#       podman run --rm localhost/hello:latest
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
        { pkgs, ... }:
        {
          oci.containers.hello = {
            package = pkgs.hello;
          };
        };
    };
}
