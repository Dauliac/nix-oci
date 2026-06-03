{
  description = "Nix OCI end-to-end tests";

  inputs = {
    get-flake.url = "github:ursi/get-flake";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    devour-flake = {
      url = "github:srid/devour-flake";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      nix-oci = inputs.get-flake ../..;
    in
    nix-oci.inputs.flake-parts.lib.mkFlake
      {
        inputs = inputs // {
          inherit nix-oci;
        };
      }
      (_: {
        imports = [
          nix-oci.flakeModules.default
        ]
        ++ inputs.nixpkgs.lib.fileset.toList (
          inputs.nixpkgs.lib.fileset.fileFilter (file: file.hasExt "nix") ../../examples
        );
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
            rootPath = ./oci;
            fromImageManifestRootPath = ./oci/pulledManifestsLocks;
          };
          perSystem =
            { pkgs, ... }:
            let
              devour-flake = pkgs.callPackage inputs.devour-flake { };
            in
            {
              apps.test = {
                type = "app";
                program =
                  pkgs.writeShellApplication {
                    name = "test";
                    runtimeInputs = [
                      devour-flake
                      pkgs.bats
                    ];
                    text = ''
                      echo "=== Nix OCI end-to-end tests ==="
                      echo ""
                      echo "=== Building all flake outputs with devour-flake ==="
                      devour-flake ../..
                      echo ""
                      echo "=== Running bats tests ==="
                      bats ./main.bats
                      echo ""
                      echo "=== All tests passed! ==="
                    '';
                  }
                  + "/bin/test";
              };
            };
        };
      });
}
