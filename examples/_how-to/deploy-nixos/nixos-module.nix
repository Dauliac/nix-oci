# NixOS module extracted from ./flake.nix so the repo's `tests/` suite can
# wrap it in its own nixosConfiguration and prove the deploy path still
# builds end-to-end against local nix-oci.
{ pkgs, ... }:
{
  boot.isContainer = true;
  system.stateVersion = "25.11";

  oci = {
    enable = true;
    backend = "podman";

    containers.my-webserver = {
      package = pkgs.python3Minimal;
      dependencies = with pkgs; [
        bashInteractive
        coreutils
      ];
      entrypoint = [
        "${pkgs.writeShellScript "serve" ''
          mkdir -p /tmp/www
          echo "Hello from nix-oci" > /tmp/www/index.html
          cd /tmp/www
          exec python3 -m http.server 8080
        ''}"
      ];
      autoStart = true;
      ports = [ "8080:8080" ];
    };
  };
}
