# How-to: Build containers from NixOS services
#
# Test: nix build .#oci-my-nginx
#       nix run .#oci-load-podman-my-nginx
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
      imports = [
        inputs.nix-oci.modules.flake.nix-oci
        # Container definition lives in ./module.nix so the repo's `tests/`
        # BDD suite can import the same module and prove this example still
        # produces the flake outputs referenced from the how-to docs.
        ./module.nix
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      oci.enabled = true;
    };
}
