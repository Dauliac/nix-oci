# OCI mkHardenedConfigs - Generate hardened /etc config files
#
# Produces derivations for hardened configuration files based on the
# container's hardening options. These are added to the image root
# filesystem, overriding default configs.
#
# Build-time only — these are baked into the image layer.
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkHardenedConfigs = {
        type = lib.types.functionTo (lib.types.listOf lib.types.package);
        description = ''
          Generate hardened /etc config file derivations from hardening options.

          When `disableDns` is set, produces:
          - Empty `/etc/resolv.conf` (no DNS servers)
          - `/etc/nsswitch.conf` with `hosts: files` only (no dns backend)

          When `noTlsTrustStore` is set, produces:
          - Empty `/etc/ssl/certs/ca-bundle.crt`

          Returns a list of derivations suitable for inclusion in `copyToRoot`
          or `configFiles`.
        '';
        fn =
          { hardening }:
          lib.optionals hardening.enable (
            lib.optionals hardening.disableDns [
              (pkgs.writeTextDir "etc/resolv.conf" "# DNS disabled by nix-oci hardening\n")
              (pkgs.writeTextDir "etc/nsswitch.conf" ''
                passwd:    files
                group:     files
                shadow:    files
                hosts:     files
                networks:  files
                ethers:    files
                services:  files
                protocols: files
                rpc:       files
              '')
            ]
            ++ lib.optionals hardening.noTlsTrustStore [
              (pkgs.writeTextDir "etc/ssl/certs/ca-bundle.crt" "# TLS trust store removed by nix-oci hardening\n")
            ]
          );
      };
    };
}
