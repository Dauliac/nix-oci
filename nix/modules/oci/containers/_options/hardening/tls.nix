# Shared: TLS trust store restriction.
{
  lib,
  ...
}:
{
  options.hardening.noTlsTrustStore = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Remove the TLS certificate trust store (`/etc/ssl/certs`).
      Prevents all outgoing HTTPS connections.

      Only use for containers that never initiate TLS connections.
      This is a nuclear option -- most applications that make any
      outbound HTTP requests will break.
    '';
  };
}
