# VM tests — NixOS integration tests that boot QEMU VMs.
#
# These are fully hermetic (no network, no daemon).
# Run: nix build .#checks.x86_64-linux.vm-deploy-integration -L
#      nix build .#checks.x86_64-linux.vm-structure -L
{ ... }:
{
  imports = [
    ./deploy.nix
    ./structure.nix
  ];
}
