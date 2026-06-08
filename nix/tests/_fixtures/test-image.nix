# Shared test fixture: minimal HTTP server OCI image.
#
# Used by both NixOS and home-manager integration tests.
# Serves "nix-oci-test-ok" on port 8080 via python3 http.server.
{
  pkgs,
  nix2container,
}:
let
  entrypoint = pkgs.writeShellScript "test-serve" ''
    mkdir -p /tmp/www
    echo "nix-oci-test-ok" > /tmp/www/index.html
    cd /tmp/www
    exec ${pkgs.python3Minimal}/bin/python3 -m http.server 8080
  '';
in
nix2container.buildImage {
  name = "test-http-server";
  tag = "test";
  copyToRoot = [
    (pkgs.buildEnv {
      name = "test-root";
      paths = with pkgs; [
        bashInteractive
        coreutils
      ];
      pathsToLink = [ "/bin" ];
    })
  ];
  config = {
    entrypoint = [ "${entrypoint}" ];
  };
}
