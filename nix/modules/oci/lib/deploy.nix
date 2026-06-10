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

            Arguments (attrset): { backend, container }
            - backend: "docker" or "podman"
            - container: container config with .image.copyToDockerDaemon and .image.copyToPodman
          '';
          file = "nix/lib/deploy.nix";
          fn = deploy.copyScript;
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
