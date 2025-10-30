# This is the public-facing flake module that bundles all nix-oci dependencies
# Users import this module and don't need to declare nix2container or other deps
inputs: {
  imports = [
    # Import the standard modules
    ./default.nix
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
