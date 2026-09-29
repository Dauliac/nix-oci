# BDD test specs for the PHP-FPM service adapter (deploy level).
#
# Covers requirement `Untested service adapters end-to-end` /
# scenario `PHP-FPM responds on FastCGI ping` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# The phpfpm adapter injects `ping.path = /ping` and
# `ping.response = pong` into the pool settings. The runtime probe
# uses `cgi-fcgi` to send a FastCGI ping and asserts the response
# body contains "pong".
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-phpfpm = {
        deploy-phpfpm-ping-returns-pong = {
          given = "a PHP-FPM container with mainService = phpfpm-web and ping.path = /ping";
          "when" = "cgi-fcgi pings the pool's FastCGI socket";
          "then" = "the response contains `pong`";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          # /run/phpfpm holds the pool socket + pid; must be writable.
          stateDirectories = [
            "/run/phpfpm"
          ];
          container = {
            isRoot = true;
            ports = [ "9000:9000" ];
            nixosConfig = {
              mainService = "phpfpm-web";
              modules = [
                (
                  { ... }:
                  {
                    services.phpfpm.pools.web = {
                      user = "nobody";
                      group = "nogroup";
                      # TCP so we can reach it over the port map;
                      # the adapter injects ping.path + ping.response.
                      settings = {
                        listen = "0.0.0.0:9000";
                        "listen.owner" = "nobody";
                        "listen.group" = "nogroup";
                        pm = "dynamic";
                        "pm.max_children" = 4;
                        "pm.start_servers" = 1;
                        "pm.min_spare_servers" = 1;
                        "pm.max_spare_servers" = 2;
                      };
                    };
                  }
                )
              ];
            };
          };
          # cgi-fcgi needs SCRIPT_FILENAME/SCRIPT_NAME env vars to
          # tell PHP-FPM which URI to route to; the ping.path handler
          # matches on the request's SCRIPT_NAME. The `succeeds`
          # helper can't set env vars per invocation, so use the
          # runtime escape hatch.
          assertions.runtime = ''
            import os, subprocess
            _env = os.environ.copy()
            _env.update({
                "SCRIPT_NAME": "/ping",
                "SCRIPT_FILENAME": "/ping",
                "REQUEST_METHOD": "GET",
                "QUERY_STRING": "",
            })
            _out = subprocess.check_output(
                ["${pkgs.fcgi}/bin/cgi-fcgi", "-bind", "-connect", "127.0.0.1:9000"],
                env=_env, timeout=15,
            ).decode("utf-8", errors="replace")
            assert "pong" in _out, (
                f"Expected `pong` in cgi-fcgi ping response, got: {_out[:500]}"
            )
          '';
        };
      };
    };
}
