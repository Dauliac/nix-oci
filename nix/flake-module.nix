# This is the public-facing flake module that bundles all nix-oci dependencies
# Users import this module and don't need to declare nix2container or other deps
inputs: {
  imports = [
    # Import nix-lib for library management (typing, testing, docs)
    inputs.nix-lib.flakeModules.default
    # Import the standard modules (manual list for external users without import-tree)
    ./modules
  ];

  # Override the package defaults to use our bundled nix2container
  config = {
    perSystem =
      { pkgs, ... }:
      {
        oci.packages = {
          nix2container = inputs.nix2container.packages.${pkgs.system}.nix2container;
          skopeo = inputs.nix2container.packages.${pkgs.system}.skopeo-nix2container;
        };
      };
  };
}
