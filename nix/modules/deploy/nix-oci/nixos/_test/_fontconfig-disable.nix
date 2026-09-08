{ lib, ... }:
{
  # Upstream nixpkgs ships a broken `etc-fonts` builder: `fontconfig-etc`
  # contains a dangling symlink `2.11/fonts.conf -> /etc/fonts/fonts.conf`
  # (a runtime-only path), and the builder dereferences it with `cp -rL`.
  # The build aborts before the VM can start. Container test VMs are
  # headless and never render text, so drop fontconfig entirely.
  # Present in fontconfig-2.17.1 on both nixos-25.11 and nixos-26.05.
  fonts.fontconfig.enable = lib.mkForce false;
}
