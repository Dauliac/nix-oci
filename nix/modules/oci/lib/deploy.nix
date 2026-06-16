# Register deploy helper functions in flake-parts nix-lib.
#
# Provides `config.lib.oci.deploy.{copyScript,autoStartContainers,mkPerfOpts,allHostPorts,mkRunArgs}`.
# Pure library: nix/lib/deploy.nix
{ ... }:
let
  deployLib = import ../../../lib/deploy.nix;
in
{
  config.perSystem =
    { lib, ... }:
    let
      deploy = deployLib { inherit lib; };
    in
    {
      nix-lib.lib.oci.deploy = {
        copyScript = {
          type = lib.types.functionTo lib.types.package;
          description = ''
            Select the backend-specific copy script for loading an OCI image.
            Returns the nix2container copy derivation.

            Three paths:
              1. registry push (copyToRegistry) — when registry is set
              2. docker daemon (copyToDockerDaemon) — direct load
              3. podman (copyToPodman) — direct load

            Arguments (attrset): { backend, container, registry ? null }
            - backend: "docker" or "podman"
            - container: container config with .image.{copyToRegistry,copyToDockerDaemon,copyToPodman}
            - registry: null or { host, port } for push-based loading
          '';
          file = "nix/lib/deploy.nix";
          fn = deploy.copyScript;
        };

        registryImageRef = {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Build the registry image reference for a container.
            Returns e.g. "localhost:5000/my-container:latest".

            Arguments (attrset): { registry, container }
            - registry: { host, port }
            - container: container config with .name and .tag
          '';
          file = "nix/lib/deploy.nix";
          fn = deploy.registryImageRef;
        };

        autoStartContainers = {
          type = lib.types.functionTo lib.types.attrs;
          description = ''
            Filter containers to only those with autoStart enabled.
          '';
          file = "nix/lib/deploy.nix";
          fn = deploy.autoStartContainers;
        };

        mkPerfOpts = {
          type = lib.types.functionTo (lib.types.listOf lib.types.str);
          description = ''
            Compute extra container runtime flags from performance.runtime options.
            Returns list of CLI flags (e.g. ["--runtime=crun" "--tmpfs=/tmp"]).
          '';
          file = "nix/lib/deploy.nix";
          fn = deploy.mkPerfOpts;
        };

        allHostPorts = {
          type = lib.types.functionTo (lib.types.listOf lib.types.int);
          description = ''
            Extract all host ports across containers for firewall rules.
            Parses port mapping specs and returns host port integers.
          '';
          file = "nix/lib/deploy.nix";
          fn = deploy.allHostPorts;
        };

        mkRunArgs = {
          type = lib.types.functionTo (lib.types.functionTo (lib.types.listOf lib.types.str));
          description = ''
            Build docker/podman run arguments for a container.
            Returns a list of CLI arguments including ports, env, volumes, and image ref.

            Usage: `mkRunArgs name container`
          '';
          file = "nix/lib/deploy.nix";
          fn = deploy.mkRunArgs;
        };
      };
    };
}
