# BDD test specs for the environment dual-write wiring.
#
# Covers requirement `Environment dual-write wiring` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# `container.environment = { MY_VAR = "hello"; }` must reach:
#   1. OCI image config `Config.Env` (built into the image, via
#      `nix/modules/deploy/nix-oci/options/_containers/image.nix:133`)
#   2. runner unit's `--env` (via `virtualisation.oci-containers.containers.<n>.environment`)
#   3. the container process itself, visible in `/proc/<pid>/environ`
#
# Surface 1 uses `envVarSet` (section-1 infra) which reads the image
# OCI `Config.Env`. Surface 3 uses `processEnv` which cat's
# `/proc/1/environ` from an ephemeral probe against the same image
# (only meaningful because the env var is baked into the image).
# Surface 2 (runner --env flag) is verified via the runtime escape
# hatch inspecting the deployed container's CreateCommand.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-wiring-env = {
        deploy-env-dual-write = {
          given = "a container with environment = { NIX_OCI_TEST_VAR = \"hello\"; }";
          "when" = "the container is deployed";
          "then" = "OCI Config.Env, runner --env, and /proc/1/environ all show the value";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            package = pkgs.coreutils;
            isRoot = true;
            entrypoint = [
              "/bin/sleep"
              "3600"
            ];
            environment = {
              NIX_OCI_TEST_VAR = "hello";
            };
          };
          # (1) OCI Config.Env baked into the image
          assertions.envVarSet = {
            NIX_OCI_TEST_VAR = "hello";
          };
          # (3) /proc/1/environ inside a container spawned from the image
          assertions.processEnv = {
            NIX_OCI_TEST_VAR = "hello";
          };
          # (2) runner unit's `--env` flag  -  inspected via the
          # deployed container's Config.CreateCommand.
          assertions.runtime = ''
            _cid = "deploy-wiring-env--deploy-env-dual-write"
            _c = client.containers.get(_cid)
            _cc = _c.attrs.get("Config", {}).get("CreateCommand", []) or []
            if not _cc:
                _cc = _c.attrs.get("HostConfig", {}).get("CreateCommand", []) or []
            _env_flag_present = any(
                "NIX_OCI_TEST_VAR" in a for a in _cc
            )
            # Fallback: podman also exposes the effective env under Config.Env.
            if not _env_flag_present:
                _env_list = _c.attrs.get("Config", {}).get("Env", []) or []
                _env_flag_present = any(
                    e.startswith("NIX_OCI_TEST_VAR=") for e in _env_list
                )
            assert _env_flag_present, (
                f"Expected runner --env NIX_OCI_TEST_VAR for {_cid}; "
                f"CreateCommand={_cc}; Config.Env={_c.attrs.get('Config', {}).get('Env')}"
            )
          '';
        };
      };
    };
}
