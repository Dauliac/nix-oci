# Flake-parts side of the "share containers between flake-parts and NixOS"
# how-to, extracted so the repo's `tests/` BDD suite can build the same
# container the standalone flake exposes.
{ ... }:
{
  config.perSystem =
    { pkgs, ... }:
    {
      config.oci.containers.my-app = import ./container.nix { inherit pkgs; };
    };
}
