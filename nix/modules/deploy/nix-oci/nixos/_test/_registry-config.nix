# NixOS config: local Docker registry for integration testing.
{
  config,
  lib,
  ...
}:
let
  cfg = config.testing;
in
lib.mkIf (cfg.enable && cfg.registry.enable) {
  services.dockerRegistry = {
    enable = true;
    port = cfg.registry.port;
  };
}
