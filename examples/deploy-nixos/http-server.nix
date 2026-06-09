# Example: NixOS deploy -- HTTP server container via nix-oci.
{ pkgs, ... }:
{
  oci = {
    enable = true;
    backend = "podman";
    containers.http-server = {
      package = pkgs.python3Minimal;
      dependencies = with pkgs; [
        bashInteractive
        coreutils
      ];
      entrypoint = [
        "${pkgs.writeShellScript "serve" ''
          mkdir -p /tmp/www
          echo "nix-oci-test-ok" > /tmp/www/index.html
          cd /tmp/www
          exec python3 -m http.server 8080
        ''}"
      ];
      autoStart = true;
      ports = [ "8080:8080" ];
    };
  };
}
