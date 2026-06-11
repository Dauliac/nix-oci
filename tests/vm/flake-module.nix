# VM tests — 2 consolidated VMs (NixOS + Debian/system-manager).
#
# These are fully hermetic (no network, no daemon).
# Run: nix build .#checks.x86_64-linux.vm-nixos -L
#      nix build .#checks.x86_64-linux.vm-system-manager -L
{ ... }:
{
  imports = [
    ./nixos.nix
    ./system-manager.nix
  ];
}
