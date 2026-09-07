# BDD test specs for NixOS Redis service example.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.nixos-redis = {
        deploy-redis-responds-to-ping = {
          given = "a NixOS container with Redis listening on port 6379";
          "when" = "the container is deployed and PING is sent";
          "then" = "Redis responds with PONG";
          # Redis is a long-running server, so the container must be
          # deployed as a daemon. `mode = "oneshot"` forces the podman
          # systemd unit to `Type = oneshot`, which waits for the
          # ExecStart to return -- podman never returns while redis is
          # running, so the service never reaches "active" and
          # `multi-user.target` never fires.
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            package = pkgs.redis;
            # Expose the container's redis port to the VM host so the
            # `docker run redis-cli -h 127.0.0.1 PING` assertion (which
            # runs *outside* the container, on the VM host) can reach
            # it. Without this the container listens on 6379 internally
            # but nothing is published.
            ports = [ "6379:6379" ];
            nixosConfig = {
              mainService = "redis-default";
              modules = [
                (
                  { ... }:
                  {
                    services.redis.servers.default = {
                      enable = true;
                      bind = "0.0.0.0";
                      port = 6379;
                      # Non-default `bind` triggers redis protected
                      # mode. The probe container reaches redis via
                      # podman's NATed port publish, so the source
                      # IP redis sees is *not* 127.0.0.1 -- protected
                      # mode then answers DENIED instead of PONG.
                      # Disable it: this is a hermetic test VM.
                      settings.protected-mode = "no";
                    };
                  }
                )
              ];
            };
          };
          assertions.succeeds = [
            {
              command = "${pkgs.redis}/bin/redis-cli";
              args = "-h 127.0.0.1 PING";
              stdout = "PONG";
            }
          ];
          exampleFile = ../../../../../../examples/flake/nixos-containers/with-nixos-redis-cst-01.nix;
        };
      };
    };
}
