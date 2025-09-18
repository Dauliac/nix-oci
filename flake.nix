{
  description = "Nix OCI";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{
      flake-parts,
      treefmt-nix,
      nix2container,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (_: {
      debug = true;
      systems = [
        "x86_64-linux"
      ];
      imports = [
        ./nix
      ];
    });
}
