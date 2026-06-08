# Top-level flake module glue.
#
# Responsibilities:
# 1. Import deploy modules at top-level (nixosModules/homeManagerModules
#    are NOT partitioned — they must be defined here, not inside dev/docs).
# 2. Export the flake-parts module via flake.modules.flake (typed API).
{ inputs, ... }:
{
  imports = [
    (inputs.import-tree ./modules/deploy)
  ];

  config.flake.modules.flake.nix-oci = import ./flake-module.nix inputs;
}
