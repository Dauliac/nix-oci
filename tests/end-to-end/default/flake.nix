{
  description = "Nix OCI tests";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nix-oci.url = "github:Dauliac/nix-oci";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      flake-parts,
      nix-oci,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (_: {
      imports = [
        inputs.nix-oci.flakeModules.default
      ];
      config = {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
          "x86_64-darwin"
        ];
        oci = {
          enabled = true;
          enableDevShell = true;
        };
        perSystem =
          { pkgs, ... }:
          {
            config.oci.containers = {
              kubectl = {
                package = pkgs.kubectl;
              };
              alpine = {
                fromImage = {
                  imageName = "library/alpine";
                  imageTag = "3.21.2";
                };
              };
            };
          };
      };
    });
}
