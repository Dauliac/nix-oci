# BDD test specs for systemd dependency wiring at deploy level.
#
# Covers requirement `Systemd dependency wiring` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# The default scenario (loader is in the runner's After+Requires)
# is exercised end-to-end: it is what `nix/modules/deploy/nix-oci/
# nixos/run-services.nix` unconditionally wires today.
#
# The extra-deps scenario (`dependencies = [ "postgresql.service" ]`
# landing in After+Requires) describes a spec requirement that has
# NO implementation in run-services.nix today (`dependencies` on the
# container currently means the closure input list, not a systemd
# ordering list). Encoded here as an inline TODO so the missing
# feature stays discoverable; the runtime hook checks the default
# wiring and leaves the extra-deps assertion to a follow-up bead.
{ ... }:
{
  perSystem =
    { ... }:
    {
      test.oci.perContainer.deploy-wiring-deps = {
        deploy-wiring-deps-loader-in-runner-after-requires = {
          given = "a deploy container with no extra dependencies";
          "when" = "the runner service is inspected via systemctl show";
          "then" = "After and Requires include the loader unit oci-load-<name>.service";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "8085:80/tcp" ];
            nixosConfig = {
              mainService = "caddy";
              modules = [
                (
                  { ... }:
                  {
                    services.caddy = {
                      enable = true;
                      virtualHosts.":80".extraConfig = ''
                        respond "wiring-deps-ok"
                      '';
                    };
                  }
                )
              ];
            };
          };
          assertions.runtime = ''
            import subprocess

            _cid = "deploy-wiring-deps--deploy-wiring-deps-loader-in-runner-after-requires"
            _loader = f"oci-load-{_cid}.service"

            # Discover the runner service name across podman/docker
            # backends.
            _runner = None
            for _prefix in ("podman-", "docker-"):
                _rc = subprocess.run(
                    ["systemctl", "show", _prefix + _cid + ".service",
                     "--property=Id"],
                    capture_output=True, text=True,
                )
                if _rc.returncode == 0 and "Id=" in _rc.stdout and _cid in _rc.stdout:
                    _runner = _prefix + _cid + ".service"
                    break
            assert _runner is not None, (
                f"Could not locate runner unit for {_cid}"
            )

            _show = subprocess.run(
                ["systemctl", "show", _runner,
                 "--property=After,Requires"],
                capture_output=True, text=True, check=True,
            )
            _props = _show.stdout
            assert _loader in _props, (
                f"Expected {_loader} in After/Requires of {_runner}, "
                f"got:\n{_props}"
            )

            # TODO(z83.6.14 follow-up): once run-services.nix grows
            # a user-facing dependencies -> systemd After+Requires
            # bridge, add a second scenario that declares
            # `dependencies = [ "postgresql.service" ]` and asserts
            # the same property carries it.
          '';
        };
      };
    };
}
