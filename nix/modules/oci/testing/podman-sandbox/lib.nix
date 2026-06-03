# Shared podman-in-sandbox infrastructure for hermetic container testing.
#
# Provides `mkPodmanSandboxCheck`, a generic builder that:
#  1. Loads a docker-archive image into rootless podman (VFS driver)
#  2. Starts the podman API socket
#  3. Runs an arbitrary test command with DOCKER_HOST pointed at the socket
#
# This runs inside the Nix build sandbox (no __noChroot).
# Requirement: `extra-sandbox-paths = /sys/fs/cgroup` in nix.conf.
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
in
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      # Podman config files shared by all hermetic checks
      policyJson = pkgs.writeText "podman-sandbox-policy.json" (
        builtins.toJSON {
          default = [ { type = "insecureAcceptAnything"; } ];
        }
      );

      storageConf = pkgs.writeText "podman-sandbox-storage.conf" ''
        [storage]
        driver = "vfs"
        rootless_storage_path = "/tmp/containers/storage"
        [storage.options]
        [storage.options.vfs]
      '';

      registriesConf = pkgs.writeText "podman-sandbox-registries.conf" ''
        [registries.search]
        registries = []
      '';

      containersConf = pkgs.writeText "podman-sandbox-containers.conf" ''
        [containers]
        log_driver = "k8s-file"
        netns = "none"
        default_sysctls = []

        [engine]
        runtime = "crun"
        cgroup_manager = "cgroupfs"
        events_logger = "file"

        [network]
        network_backend = "netavark"
      '';
    in
    {
      nix-lib.lib.oci = {
        mkPodmanSandboxCheck = {
          type = types.functionTo types.package;
          description = ''
            Run a test command inside the Nix sandbox with a podman daemon.
            Loads a docker-archive OCI image into podman, starts the API
            socket, then executes the given testScript with DOCKER_HOST set.
          '';
          fn =
            {
              # Derivation name
              name,
              # Docker-archive tar of the image to test
              dockerArchive,
              # Full image reference after loading (e.g. "localhost/test-image:latest")
              imageRef,
              # Shell script to execute. Has access to DOCKER_HOST, PODMAN_FLAGS, etc.
              testScript,
              # Extra nativeBuildInputs for the test (e.g. container-structure-test, dgoss)
              extraBuildInputs ? [ ],
              # Optional extra setup script (runs before image load)
              extraSetup ? "",
            }:
            pkgs.runCommand name
              {
                nativeBuildInputs = [
                  pkgs.podman
                  pkgs.crun
                  pkgs.conmon
                  pkgs.coreutils
                  pkgs.bash
                  pkgs.util-linux
                ]
                ++ extraBuildInputs;
              }
              ''
                set -euo pipefail
                export HOME=/tmp/home
                mkdir -p $HOME

                export XDG_RUNTIME_DIR=/tmp/run-$$
                export XDG_DATA_HOME=/tmp/data
                export XDG_CONFIG_HOME=$HOME/.config
                mkdir -p $XDG_RUNTIME_DIR $XDG_DATA_HOME $XDG_CONFIG_HOME

                # Write podman config files
                mkdir -p $XDG_CONFIG_HOME/containers
                cp ${policyJson} $XDG_CONFIG_HOME/containers/policy.json
                cp ${containersConf} $XDG_CONFIG_HOME/containers/containers.conf
                cp ${registriesConf} $XDG_CONFIG_HOME/containers/registries.conf
                cp ${storageConf} $XDG_CONFIG_HOME/containers/storage.conf

                mkdir -p /tmp/containers/storage /tmp/containers/runroot

                PODMAN_FLAGS=(
                  --storage-driver=vfs
                  --root=/tmp/containers/storage
                  --runroot=/tmp/containers/runroot
                )

                ${extraSetup}

                # Load image and tag it with the expected reference.
                # skopeo's docker-archive format may not embed repo tags, so
                # podman load returns a bare sha256 digest. We capture that
                # and tag it so test tools can find the image by name.
                LOADED=$(podman "''${PODMAN_FLAGS[@]}" load -i ${dockerArchive} \
                  | sed -n 's/^Loaded image: //p')
                if [ -n "$LOADED" ]; then
                  podman "''${PODMAN_FLAGS[@]}" tag "$LOADED" "${imageRef}" 2>/dev/null || true
                fi

                # Start podman API socket in background
                podman "''${PODMAN_FLAGS[@]}" \
                  system service --time=300 \
                  unix://$XDG_RUNTIME_DIR/podman.sock &
                PODMAN_PID=$!

                # Wait for socket to be ready
                for _i in $(seq 1 30); do
                  [ -S $XDG_RUNTIME_DIR/podman.sock ] && break
                  sleep 0.3
                done
                if [ ! -S $XDG_RUNTIME_DIR/podman.sock ]; then
                  echo "ERROR: Podman API socket not created" >&2
                  kill $PODMAN_PID 2>/dev/null || true
                  exit 1
                fi

                export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman.sock

                # Run the test
                ${testScript}

                # Cleanup
                kill $PODMAN_PID 2>/dev/null || true
                wait $PODMAN_PID 2>/dev/null || true

                mkdir -p $out
                touch $out/passed
              '';
        };
      };
    };
}
