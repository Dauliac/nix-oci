{ ... }:
{
  flake.templates = {
    default = {
      path = ../templates/default;
      description = ''
        A minimal flake using flake-parts and nix-oci.
      '';
    };
  };
}
