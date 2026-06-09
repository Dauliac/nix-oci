# Example: home-manager deploy -- HTTP server container via nix-oci.
#
# Uses writeShellApplication for a proper package derivation.
{ pkgs, ... }:
let
  http-server = pkgs.writeShellApplication {
    name = "http-server";
    runtimeInputs = with pkgs; [
      python3Minimal
      coreutils
    ];
    text = ''
      mkdir -p /tmp/www
      echo "nix-oci-test-ok" > /tmp/www/index.html
      cd /tmp/www
      exec python3 -m http.server 8080
    '';
  };
in
{
  oci = {
    enable = true;
    backend = "podman";
    containers.http-server = {
      package = http-server;
      dependencies = [ pkgs.coreutils ];
      autoStart = true;
      ports = [ "9090:8080" ];
    };
  };
}
