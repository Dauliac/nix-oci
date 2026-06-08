# Shared: DNS resolution restriction.
{ lib, ... }:
{
  options.hardening.disableDns = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Disable DNS resolution inside the container.

      Sets `/etc/resolv.conf` to empty and `/etc/nsswitch.conf`
      hosts line to `files` only. Applications using IP addresses
      directly are unaffected.

      In the inner NixOS module, this overrides the default
      nsswitch.conf to remove the `dns` backend from the `hosts`
      entry.
    '';
  };
}
