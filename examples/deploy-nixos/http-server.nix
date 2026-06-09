# Example: NixOS deploy -- HTTP server container via nix-oci.
#
# Static content is baked into the image via dependencies with writeTextDir.
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
      dependencies = [
        pkgs.coreutils
        (pkgs.writeTextDir "var/www/index.html" "nix-oci-test-ok\n")
      ];
      autoStart = true;
      ports = [ "8080:8080" ];
    };
  };
}
