# This is the public-facing flake module that bundles all nix-oci dependencies
# Users import this module and don't need to declare nix2container or other deps
inputs: {
  imports = [
    # Import nix-lib for library management (typing, testing, docs)
    inputs.nix-lib.flakeModules.default
    # Enable typed flake.modules.{nixos,homeManager,...} output
    inputs.flake-parts.flakeModules.modules
    # Auto-discover all modules using import-tree
    (inputs.import-tree ./modules)
  ];

  # Override the package defaults to use our bundled dependencies
  config = {
    perSystem =
      { system, ... }:
      {
        oci.packages = {
          nix2container = inputs.nix2container.packages.${system}.nix2container;
          skopeo = inputs.nix2container.packages.${system}.skopeo-nix2container;
        };
      };
  };
}
