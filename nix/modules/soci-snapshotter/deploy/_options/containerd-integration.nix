# services.soci-snapshotter.containerdIntegration — auto-configure containerd.
{ lib, ... }:
{
  options.services.soci-snapshotter.containerdIntegration = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to automatically register the SOCI snapshotter as a
      containerd proxy plugin. When true, the containerd config.toml
      is extended with the appropriate proxy_plugins entry.

      Set to false if you manage containerd configuration manually.
    '';
  };
}
