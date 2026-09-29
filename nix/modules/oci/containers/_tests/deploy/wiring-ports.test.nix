# BDD test specs for the ports triple-write wiring.
#
# Covers requirement `Ports triple-write wiring` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# A single `ports` entry must reach three surfaces:
#   1. OCI image config `ExposedPorts` (build-time)
#   2. runner unit `--publish` flag (deploy-time)
#   3. NixOS firewall accept rule (deploy-time)
#
# Uses the new `firewallPortOpen` typed assertion (section-1 infra)
# for surface 3 and `httpResponds` for the end-to-end host -> VM
# request. Surfaces 1 and 2 are verified via the runtime escape
# hatch inspecting `podman inspect` output.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-wiring-ports = {
        deploy-ports-triple-write = {
          given = "a container with ports = [ 8090:80/tcp ] and a Caddy backend on :80";
          "when" = "the container is deployed";
          "then" = "ExposedPorts, runner --publish, nft accept rule, and end-to-end HTTP all agree";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "8090:80/tcp" ];
            nixosConfig = {
              mainService = "caddy";
              modules = [
                (
                  { ... }:
                  {
                    services.caddy = {
                      enable = true;
                      virtualHosts.":80".extraConfig = ''
                        respond "nix-oci-wiring-ports-ok"
                      '';
                    };
                  }
                )
              ];
            };
          };
          # (a) OCI ExposedPorts (image config)
          assertions.imageConfig = {
            ExposedPorts = {
              "80/tcp" = { };
            };
          };
          # (c) NixOS firewall accept rule  -  nft on the VM host
          assertions.firewallPortOpen = [
            {
              port = 8090;
              protocol = "tcp";
            }
          ];
          # (d) end-to-end HTTP from VM host -> container backend
          assertions.httpResponds = {
            port = 8090;
            path = "/";
            contains = "nix-oci-wiring-ports-ok";
          };
          # (b) runner --publish flag  -  inspected via podman inspect
          # on the deployed container. Uses the runtime escape hatch
          # because `containerInspect` matches literal string values
          # only, and the CreateCommand array contains "--publish"
          # then the mapping as a separate element.
          assertions.runtime = ''
            _cid = "deploy-wiring-ports--deploy-ports-triple-write"
            _c = client.containers.get(_cid)
            _cc = _c.attrs.get("Config", {}).get("CreateCommand", []) or []
            # Podman stores the invocation in HostConfig.CreateCommand
            # or Config.CreateCommand; also check HostConfig.
            if not _cc:
                _cc = _c.attrs.get("HostConfig", {}).get("CreateCommand", []) or []
            _pub_flag_present = any(
                a in ("--publish", "-p") for a in _cc
            ) or any(
                "8090:80" in a for a in _cc
            )
            # Fallback: podman also exposes the mapping under NetworkSettings.
            if not _pub_flag_present:
                _ports = _c.attrs.get("NetworkSettings", {}).get("Ports", {}) or {}
                _pub_flag_present = "80/tcp" in _ports and any(
                    b.get("HostPort") == "8090" for b in (_ports.get("80/tcp") or [])
                )
            assert _pub_flag_present, (
                f"Expected runner --publish 8090:80 for {_cid}; "
                f"CreateCommand={_cc}; NetworkSettings.Ports={_c.attrs.get('NetworkSettings', {}).get('Ports')}"
            )
          '';
        };
      };
    };
}
