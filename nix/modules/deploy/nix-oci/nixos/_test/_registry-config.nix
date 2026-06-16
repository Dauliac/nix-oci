# NixOS config: local Docker registry for integration testing.
{ lib, ... }:
{
  services.dockerRegistry = {
    enable = lib.mkDefault true;
    port = lib.mkDefault 5000;
  };
}
