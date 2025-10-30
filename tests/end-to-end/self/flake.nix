{
  description = "Nix OCI tests";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nix-oci.url = "path:../../..";
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
      ]
      ++ inputs.nixpkgs.lib.fileset.toList (
        inputs.nixpkgs.lib.fileset.fileFilter (file: file.hasExt "nix") ../../../examples
      );
      config = {
        oci.enabled = true;
        oci.enableDevShell = true;
        oci.rootPath = ./oci;
        oci.fromImageManifestRootPath = ./oci/pulledManifestsLocks;
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
          "x86_64-darwin"
        ];
      };
    });
}
