# Example: home-manager deploy -- HTTP server container via nix-oci.
#
# Uses writeShellApplication for a proper package and configFiles to bake
# the index.html into the container image at build time (no runtime echo).
{ pkgs, ... }:
let
  http-server = pkgs.writeShellApplication {
    name = "http-server";
    runtimeInputs = [ pkgs.python3Minimal ];
    text = ''
      cd /var/www
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
      configFiles = [
        (pkgs.writeTextDir "var/www/index.html" "nix-oci-test-ok\n")
      ];
      autoStart = true;
      ports = [ "9090:8080" ];
    };
  };
}
