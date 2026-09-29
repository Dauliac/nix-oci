# BDD test specs for the Postfix service adapter (deploy level).
#
# Covers requirement `Untested service adapters end-to-end` /
# scenario `Postfix reports ready` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# `postfix status` must run INSIDE the deployed container (the
# postfix command talks to the local master over its Unix socket).
# The `succeeds` helper only runs ephemeral probe containers, so
# this scenario uses the runtime escape hatch to `docker exec` into
# the deployed container.
{ ... }:
{
  perSystem =
    { ... }:
    {
      test.oci.perContainer.deploy-postfix = {
        deploy-postfix-status-reports-master-pid = {
          given = "a Postfix container with mainService = postfix";
          "when" = "`postfix status` runs inside the container";
          "then" = "the output reports the master pid";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          stateDirectories = [
            "/var/lib/postfix"
            "/var/spool/postfix"
            "/run/postfix"
          ];
          container = {
            isRoot = true;
            nixosConfig = {
              mainService = "postfix";
              modules = [
                (
                  { ... }:
                  {
                    services.postfix = {
                      enable = true;
                      hostname = "test.local";
                      # keep it minimal; postfix status doesn't need
                      # any relay or user config.
                    };
                  }
                )
              ];
            };
          };
          # `docker exec` into the deployed container so postfix
          # can talk to its local master via the config directory
          # baked into the image. The container name mirrors the
          # spec key with `--` as the group/scenario separator.
          assertions.runtime = ''
            _cid = "deploy-postfix--deploy-postfix-status-reports-master-pid"
            _c = client.containers.get(_cid)
            _rc, _out = _c.exec_run("postfix status")
            _text = _out.decode("utf-8", errors="replace") if isinstance(_out, bytes) else str(_out)
            assert "master" in _text.lower() or "pid" in _text.lower(), (
                f"Expected `postfix status` to report master pid, got: {_text[:500]}"
            )
          '';
        };
      };
    };
}
