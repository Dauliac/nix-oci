# Container hardening options (flake-parts wrapper).
#
# Imports all shared hardening option definitions from _options/hardening/
# into the per-container module.
{ ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          imports = [
            ./_options/hardening/enable.nix
            ./_options/hardening/dns.nix
            ./_options/hardening/tls.nix
            ./_options/hardening/seccomp.nix
            ./_options/hardening/capabilities.nix
            ./_options/hardening/rootfs.nix
            ./_options/hardening/privileges.nix
          ];
        };
    };
}
