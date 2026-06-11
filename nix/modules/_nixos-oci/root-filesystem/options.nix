{ lib, ... }:
{
  options.oci.container = {
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Main package for the container.";
    };
    dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to include in the root filesystem.";
    };
    _output.adapterPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Packages explicitly added by service adapters (e.g. dig for dnsmasq
        healthcheck, fcgi for phpfpm). These are included in the container
        root filesystem instead of environment.systemPackages to avoid
        pulling in the full NixOS default package set.
      '';
    };
  };
}
