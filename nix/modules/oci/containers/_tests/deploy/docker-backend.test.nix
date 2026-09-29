# BDD test specs for the docker backend deploy path.
#
# Covers requirement `Docker backend deploy runtime` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# Reuses the shape of `nixos-caddy.test.nix`  -  one Caddy container
# responding with a fixed body. The docker backend is engaged by
# setting `config.test.oci._vmBackend = "docker"` on the consuming
# flake (see `nix/modules/oci/testing/test-vm.nix`, which flips the
# NixOS `oci.backend` and enables `virtualisation.docker`).
#
# Because `_vmBackend` is a top-level harness setting (not a per-spec
# override), the scenario name is distinct so it can co-exist with
# the podman scenario in the same run. In CI the harness is
# invoked twice: once with the default podman backend, once with
# docker, and this scenario's HTTP assertion is expected to pass in
# both.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-docker-backend = {
        deploy-caddy-serves-http-under-docker = {
          given = "the nixos-caddy scenario re-run with _vmBackend = docker";
          "when" = "the container is deployed and HTTP is requested";
          "then" = "Caddy responds with the configured content";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "8091:8090" ];
            nixosConfig = {
              mainService = "caddy";
              modules = [
                (
                  { pkgs, ... }:
                  {
                    services.caddy = {
                      enable = true;
                      virtualHosts.":8090".extraConfig = ''
                        respond "nix-oci-caddy-docker-ok"
                      '';
                    };
                    environment.systemPackages = [ pkgs.curl ];
                  }
                )
              ];
            };
          };
          assertions.httpResponds = {
            port = 8091;
            path = "/";
            contains = "nix-oci-caddy-docker-ok";
          };
        };
      };
    };
}
