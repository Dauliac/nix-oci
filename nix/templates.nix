{ ... }:
{
  flake.templates = {
    default = {
      path = ../tests/end-to-end/default;
      description = ''
        A minimal flake using flake-parts and nix-oci.
      '';
    };
  };
}
