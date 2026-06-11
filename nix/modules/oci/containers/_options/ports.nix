# Shared: port mappings (used by deploy runner + OCI ExposedPorts).
{
  lib,
  pkgs,
  ...
}:
let
  example = [
    "8080:8080"
    "443:443"
  ];
in
{
  options.ports = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Port mappings (e.g. `["8080:8080"]`).
      Baked into OCI manifest ExposedPorts and used by the runner service.
    '';
    inherit example;
  };

  config._tests.ports = {
    level = "inspect";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      ports = example;
    };
    assertions.imageConfig.ExposedPorts = {
      "8080/tcp" = { };
      "443/tcp" = { };
    };
  };
}
