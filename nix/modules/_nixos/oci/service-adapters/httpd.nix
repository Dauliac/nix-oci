# Apache httpd: run in foreground
#
# NixOS httpd uses Type=forking. Apache requires the -DFOREGROUND
# command-line flag to stay in the foreground — there is no config
# file directive equivalent.
#
# We replace the httpd package with a thin wrapper that always passes
# -DFOREGROUND, preserving all modules and helpers from the original
# package. The NixOS module picks up the wrapper via services.httpd.package.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
  originalPkg = config.services.httpd.package;
  httpdForeground = pkgs.symlinkJoin {
    name = "httpd-foreground";
    paths = [ originalPkg ];
    postBuild = ''
      rm "$out/bin/httpd"
      cat > "$out/bin/httpd" <<'WRAPPER'
      #!/bin/sh
      exec ${originalPkg}/bin/httpd -DFOREGROUND "$@"
      WRAPPER
      chmod +x "$out/bin/httpd"
    '';
  };
in
{
  config = lib.mkIf (cfg.mainService == "httpd") {
    services.httpd.package = lib.mkForce httpdForeground;
    systemd.services.httpd.serviceConfig.Type = lib.mkForce "simple";
  };
}
