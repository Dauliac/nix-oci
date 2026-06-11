# All CST tests have been migrated to VM tests:
#   - Basic structure: tests/vm/structure.nix
#   - Hardening: tests/vm/hardening.nix
#   - NixOS containers (jq, devShell, postgres): tests/vm/nixos-containers.nix
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = { };
      };
  };
}
