# BDD test specs for the ports triple-write wiring at deploy level.
#
# Covers requirement `Ports triple-write wiring` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# `ports = [ "8082:80/tcp" ]` must reach FOUR destinations:
#  1. the OCI image's ExposedPorts (via nix2container config)
#  2. the runner service's --publish flag (via
#     virtualisation.oci-containers.containers.<n>.ports)
#  3. the NixOS firewall's allowedTCPPorts (via
#     run-services.nix -> deployLib.allHostPorts)
#  4. an actual end-to-end TCP path (VM host -> container listener)
#
# The runtime escape hatch inspects (1) via `docker inspect`, (2)
# and (3) via `subprocess` calls to systemctl/nft on the VM host,
# and (4) via `requests.get` to the published host port.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-wiring-ports = {
        deploy-wiring-ports-triple-write = {
          given = "a Caddy deploy container with ports = [ 8082:80/tcp ]";
          "when" = "the loader + runner boot and an HTTP client hits :8082 on the VM host";
          "then" = "ExposedPorts contains 80/tcp, the runner --publishes 8082:80, nft accepts 8082, and the request round-trips";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "8082:80/tcp" ];
            nixosConfig = {
              mainService = "caddy";
              modules = [
                (
                  { ... }:
                  {
                    services.caddy = {
                      enable = true;
                      virtualHosts.":80".extraConfig = ''
                        respond "wiring-ports-ok"
                      '';
                    };
                  }
                )
              ];
            };
          };
          assertions.runtime = ''
            import subprocess
            import requests
            import time

            _cid = "deploy-wiring-ports--deploy-wiring-ports-triple-write"

            # (1) OCI image ExposedPorts contains 80/tcp
            _img = client.images.get(_cid + ":latest")
            _exposed = (_img.attrs.get("Config") or {}).get("ExposedPorts") or {}
            assert "80/tcp" in _exposed, (
                f"Expected ExposedPorts to contain 80/tcp, got: {list(_exposed)}"
            )

            # (2) runner unit --publishes 8082:80. Read the ExecStart
            # from systemctl; the podman/docker CLI carries the flag.
            _svc = subprocess.run(
                ["systemctl", "cat", "podman-" + _cid + ".service"],
                capture_output=True, text=True,
            )
            _unit = _svc.stdout + _svc.stderr
            if "podman-" not in _unit and "docker-" not in _unit:
                # backend may be docker; try that unit name.
                _svc = subprocess.run(
                    ["systemctl", "cat", "docker-" + _cid + ".service"],
                    capture_output=True, text=True,
                )
                _unit = _svc.stdout + _svc.stderr
            assert "--publish" in _unit and "8082:80" in _unit, (
                f"Expected --publish 8082:80 in runner unit, got:\n{_unit[:2000]}"
            )

            # (3) NixOS firewall accepts 8082 on the input chain.
            _nft = subprocess.run(
                ["nft", "list", "ruleset"], capture_output=True, text=True,
            )
            _rules = _nft.stdout
            assert "8082" in _rules, (
                f"Expected port 8082 in nft ruleset, got:\n{_rules[:2000]}"
            )

            # (4) End-to-end: HTTP request against the published port.
            _deadline = time.time() + 30
            _last = None
            while time.time() < _deadline:
                try:
                    _r = requests.get("http://127.0.0.1:8082/", timeout=5)
                    _r.raise_for_status()
                    break
                except Exception as _exc:
                    _last = _exc
                    time.sleep(1)
            else:
                raise TimeoutError(f":8082 never answered: {_last}")
            assert "wiring-ports-ok" in _r.text, (
                f"Expected 'wiring-ports-ok' body, got: {_r.text[:500]}"
            )
          '';
        };
      };
    };
}
