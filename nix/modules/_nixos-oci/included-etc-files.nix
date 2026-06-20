# Unified /etc file inclusion option.
#
# Any _nixos-oci module can register /etc file names for container inclusion.
# Only registered files are extracted from NixOS environment.etc into the
# container image. This prevents bloat from NixOS default /etc files
# (os-release, machine-id, shells, systemd configs, etc.).
#
# Modules declare files via NixOS environment.etc AND register them here:
#   - environment/outputs.nix registers "nsswitch.conf", "ssl/certs/ca-bundle.crt"
#   - nix-support/outputs.nix registers "nix/nix.conf"
#   - hardening/config.nix may override "nsswitch.conf" for DNS disable
{ lib, ... }:
{
  options.oci.container.includedEtcFiles = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ "nsswitch.conf" ];
    description = ''
      Names of /etc files to extract into the container image.

      Only files listed here are extracted from NixOS `environment.etc`.
      This prevents the container from being bloated with NixOS default
      /etc files that are useless in containers (os-release, machine-id,
      shells, systemd configs, etc.).

      Modules that declare /etc files via `environment.etc` should also
      register the file name here so it gets included in the image.

      NixOS service configs (nginx.conf, redis.conf, etc.) do NOT need
      to be listed here -- NixOS services reference configs via Nix
      store paths, not /etc.
    '';
  };
}
