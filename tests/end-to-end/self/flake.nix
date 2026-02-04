{
  description = "Nix OCI tests";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    get-flake.url = "github:ursi/get-flake";
  };

  outputs =
    inputs@{
      flake-parts,
      get-flake,
      ...
    }:
    let
      # Use get-flake to reference parent flake without sandbox issues
      nix-oci = get-flake ../../..;
    in
    flake-parts.lib.mkFlake { inherit inputs; } (_: {
      imports = [
        nix-oci.flakeModules.default
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
