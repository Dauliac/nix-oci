# Image structure test -- system-manager on Debian 13 (non-NixOS).
#
# Isomorphic with structure.nix: same containers, same assertions,
# different deployment backend.
#
# Run: nix build .#checks.x86_64-linux.vm-structure-system-manager -L
{
  inputs,
  config,
  ...
}:
let
  structureTestScript = import ./_shared/structure-test-script.nix;
in
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      mkSystemManagerTest = import ./_shared/mk-system-manager-test.nix {
        inherit
          inputs
          config
          pkgs
          lib
          system
          ;
      };
      containers = import ./_shared/structure-containers.nix { inherit pkgs; };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-structure-system-manager = mkSystemManagerTest {
          name = "nix-oci-structure-sm";
          inherit containers;
          testBody = ''
            ${structureTestScript}
            run_structure_tests(vm)
          '';
        };
      };
    };
}
