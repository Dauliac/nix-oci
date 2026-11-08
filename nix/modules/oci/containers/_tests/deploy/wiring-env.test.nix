# BDD test specs for the environment dual-write wiring at deploy level.
#
# Covers requirement `Environment dual-write wiring` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# `environment.MY_VAR = "hello"` must reach THREE destinations:
#  1. the OCI image's Env array (baked into the image config)
#  2. the runner service's --env flag (via
#     virtualisation.oci-containers.containers.<n>.environment)
#  3. the container process's /proc/<pid>/environ (the daemon
#     actually sees the value)
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-wiring-env = {
        deploy-wiring-env-dual-write = {
          given = "a Caddy deploy container with environment.MY_VAR = hello";
          "when" = "the loader + runner boot as daemon";
          "then" =
            "the image Env contains MY_VAR=hello, the runner --env carries it, and /proc/1/environ inside the container shows it";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "8083:80/tcp" ];
            environment.MY_VAR = "hello";
            nixosConfig = {
              mainService = "caddy";
              modules = [
                (
                  { pkgs, ... }:
                  {
                    services.caddy = {
                      enable = true;
                      virtualHosts.":80".extraConfig = ''
                        respond "wiring-env-ok"
                      '';
                    };
                    # Test-only: assertion (3) below execs `cat
                    # /proc/1/environ` inside this container; Caddy's
                    # scratch image has no coreutils by default.
                    oci.container.extraPackages = [ pkgs.coreutils ];
                  }
                )
              ];
            };
          };
          assertions.runtime = ''
            import subprocess

            _cid = "deploy-wiring-env--deploy-wiring-env-dual-write"

            # (1) OCI image Env contains MY_VAR=hello.
            _img = client.images.get(_cid + ":latest")
            _env = (_img.attrs.get("Config") or {}).get("Env") or []
            assert "MY_VAR=hello" in _env, (
                f"Expected MY_VAR=hello in image Env, got: {_env}"
            )

            # (2) Runner unit carries --env MY_VAR=hello (or an
            # equivalent -e MY_VAR=hello). Try both backend service
            # name prefixes.
            _unit = ""
            for _prefix in ("podman-", "docker-"):
                _svc = subprocess.run(
                    ["systemctl", "cat", _prefix + _cid + ".service"],
                    capture_output=True, text=True,
                )
                if _svc.returncode == 0 and _svc.stdout:
                    _unit = _svc.stdout
                    break
            # nixpkgs' virtualisation.oci-containers module writes the
            # full podman/docker run invocation -- including --env --
            # into a generated wrapper script, not inline in the
            # unit's own Environment= lines; ExecStart just points at
            # it. Read that script too so this checks the actual
            # runner invocation, not just the unit's pointer to it.
            _script_path = ""
            for _line in _unit.splitlines():
                if _line.startswith("ExecStart="):
                    _script_path = _line[len("ExecStart="):].strip()
                    break
            _script_body = ""
            if _script_path:
                _cat = subprocess.run(
                    ["cat", _script_path], capture_output=True, text=True,
                )
                _script_body = _cat.stdout
            _combined = _unit + "\n" + _script_body
            assert "MY_VAR=hello" in _combined, (
                f"Expected MY_VAR=hello in runner unit or its start script, got:\n{_combined[:2000]}"
            )

            # (3) /proc/1/environ inside the running container shows
            # the value. docker exec into the daemon container.
            _c = client.containers.get(_cid)
            _rc, _out = _c.exec_run(["cat", "/proc/1/environ"])
            _raw = _out.decode("utf-8", errors="replace") if isinstance(_out, bytes) else str(_out)
            _pairs = _raw.split("\x00")
            assert "MY_VAR=hello" in _pairs, (
                f"Expected MY_VAR=hello in /proc/1/environ, got: {_pairs[:20]}"
            )
          '';
        };
      };
    };
}
