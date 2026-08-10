# How-to: Build and run with flake-parts
#
# Test: nix build .#oci-hello
#       nix run .#oci-load-podman-hello
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
