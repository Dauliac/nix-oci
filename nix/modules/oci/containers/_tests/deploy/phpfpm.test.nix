# BDD test specs for the PHP-FPM service adapter (deploy level).
#
# Covers requirement `Untested service adapters end-to-end` /
# scenario `PHP-FPM responds on FastCGI ping` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# The phpfpm adapter injects ping.path = /ping into the pool
# settings and picks fcgi as the healthcheck client. The runtime
# probe re-uses cgi-fcgi from an ephemeral container against the
# VM host's published TCP socket, asserting the pool responds pong.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-phpfpm = {
        deploy-phpfpm-ping-returns-pong = {
          given = "a PHP-FPM container with mainService = phpfpm-web and ping.path = /ping";
          "when" = "cgi-fcgi -bind -connect <addr> issues a FastCGI request for /ping";
          "then" = "the pool responds with pong";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "9000:9000/tcp" ];
            nixosConfig = {
              mainService = "phpfpm-web";
              modules = [
                (
                  { pkgs, ... }:
                  {
                    services.phpfpm.pools.web = {
                      user = "nobody";
                      group = "nogroup";
                      phpPackage = pkgs.php;
                      # TCP socket so cgi-fcgi from the VM host can
                      # reach the pool via the published port map.
                      settings = {
                        "listen" = "0.0.0.0:9000";
                        "listen.owner" = "nobody";
                        "listen.group" = "nogroup";
                        "pm" = "static";
                        "pm.max_children" = 1;
                        # ping.path/ping.response are injected by the
                        # adapter with mkDefault; leave them alone.
                      };
                    };
                    users.users.nobody.group = "nogroup";
                    users.groups.nogroup = { };
                  }
                )
              ];
            };
          };
          # cgi-fcgi sends a FastCGI PING request and prints the
          # pool's ping.response body (default "pong") on stdout.
          assertions.succeeds = [
            {
              command = "${pkgs.fcgi}/bin/cgi-fcgi";
              args = "-bind -connect 127.0.0.1:9000 /ping";
              stdout = "pong";
            }
          ];
        };
      };
    };
}
