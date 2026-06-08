# Shared container definition — used by both flake-parts (CI) and NixOS (deploy).
{ pkgs }:
{
  package = pkgs.python3Minimal;
  dependencies = with pkgs; [
    bashInteractive
    coreutils
  ];
  entrypoint = [
    "${pkgs.writeShellScript "serve" ''
      mkdir -p /tmp/www
      echo "Hello from shared container" > /tmp/www/index.html
      cd /tmp/www
      exec python3 -m http.server 8080
    ''}"
  ];
  ports = [ "8080:8080" ];
}
