# Image structure test -- validates container contents in a NixOS VM.
#
# Uses shared container definitions and test script from _shared/.
# Isomorphic with structure-system-manager.nix (same containers, same assertions).
#
# Run: nix build .#checks.x86_64-linux.vm-structure -L
{ config, ... }:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
  structureTestScript = import ./_shared/structure-test-script.nix;
in
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      testHelpers = import ../lib.nix { inherit pkgs lib; };
      containers = import ./_shared/structure-containers.nix { inherit pkgs; };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-structure = testHelpers.mkVMTest {
          name = "nix-oci-structure";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [ nixosModule ];

              virtualisation.podman.enable = true;

              oci = {
                enable = true;
                backend = "podman";
                inherit containers;
              };
            };

          testScript = ''
            ${structureTestScript}

            machine.wait_for_unit("multi-user.target")
            run_structure_tests(machine)
          '';
        };
      };
    };
}
