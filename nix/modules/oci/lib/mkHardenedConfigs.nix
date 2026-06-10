# OCI mkHardenedConfigs - Generate hardened /etc config files
#
# Produces derivations for hardened configuration files based on the
# container's hardening options. These are added to the image root
# filesystem, overriding default configs.
#
# Build-time only -- these are baked into the image layer.
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
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
          - `/etc/nsswitch.conf` with `hosts: files` only (no dns backend)

          NOTE: `/etc/resolv.conf` is NOT written -- container runtimes always
          bind-mount it at startup, masking any image content.

          When `noTlsTrustStore` is set, produces:
          - Empty `/etc/ssl/certs/ca-bundle.crt`

          Returns a list of derivations suitable for inclusion in `copyToRoot`
          or `dependencies`.
        '';
        file = "nix/modules/oci/lib/mkHardenedConfigs.nix";
        fn = { hardening }: pure.mkHardenedConfigs { inherit hardening pkgs; };
      };
    };
}
