# Resolve Apache httpd listen facts from services.httpd.virtualHosts
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  nix-lib.lib.oci.resolveHttpdListen = {
    type = lib.types.functionTo lib.types.attrs;
    description = "Derive an httpd container's detected ports, health probe port, and TLS-only flag from `services.httpd.virtualHosts`, mirroring nixpkgs' mkListenInfo";
    file = "nix/modules/oci/lib/ociResolveHttpdListen.nix";
    fn = { virtualHosts }: pure.resolveHttpdListen { inherit virtualHosts; };
    tests = {
      "falls back to port 80 when no virtual host is defined" = {
        args.virtualHosts = { };
        expected = {
          detectedPorts = [ 80 ];
          healthPort = 80;
          usesSsl = false;
        };
      };
      "defaults a plain virtual host to port 80" = {
        args.virtualHosts.localhost = {
          listen = [ ];
          listenAddresses = [ "*" ];
          onlySSL = false;
          addSSL = false;
          forceSSL = false;
        };
        expected = {
          detectedPorts = [ 80 ];
          healthPort = 80;
          usesSsl = false;
        };
      };
      "reports both ports when SSL is added alongside plaintext" = {
        args.virtualHosts.localhost = {
          listen = [ ];
          listenAddresses = [ "*" ];
          onlySSL = false;
          addSSL = true;
          forceSSL = false;
        };
        expected = {
          detectedPorts = [
            443
            80
          ];
          healthPort = 80;
          usesSsl = false;
        };
      };
      "probes TLS and skips verification when onlySSL" = {
        args.virtualHosts.localhost = {
          listen = [ ];
          listenAddresses = [ "*" ];
          onlySSL = true;
          addSSL = false;
          forceSSL = false;
        };
        expected = {
          detectedPorts = [ 443 ];
          healthPort = 443;
          usesSsl = true;
        };
      };
      "an explicit listen wins over the SSL defaults" = {
        args.virtualHosts.localhost = {
          listen = [
            {
              ip = "*";
              port = 8080;
              ssl = false;
            }
          ];
          listenAddresses = [ "*" ];
          onlySSL = false;
          addSSL = true;
          forceSSL = true;
        };
        expected = {
          detectedPorts = [ 8080 ];
          healthPort = 8080;
          usesSsl = false;
        };
      };
      "deduplicates ports across virtual hosts" = {
        args.virtualHosts = {
          a = {
            listen = [ ];
            listenAddresses = [ "*" ];
            onlySSL = false;
            addSSL = false;
            forceSSL = false;
          };
          b = {
            listen = [ ];
            listenAddresses = [ "*" ];
            onlySSL = false;
            addSSL = false;
            forceSSL = false;
          };
        };
        expected = {
          detectedPorts = [ 80 ];
          healthPort = 80;
          usesSsl = false;
        };
      };
    };
  };
}
