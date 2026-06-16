# Shared: DNS resolution restriction.
{
  lib,
  ...
}:
{
  options.hardening.disableDns = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Disable DNS resolution inside the container.

      Sets `/etc/nsswitch.conf` hosts line to `files` only (no `dns`
      backend). Applications using IP addresses directly are unaffected.

      NOTE: `/etc/resolv.conf` is NOT written into the image because
      container runtimes (Docker, Podman) always bind-mount it at
      startup, masking any baked-in content. To fully enforce DNS
      restriction at runtime, use `--dns=127.0.0.1` or network
      policies.
    '';
  };
}
