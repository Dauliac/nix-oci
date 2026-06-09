# OCI mkSandbox - Generate a bubblewrap sandbox script for a container
#
# Uses the container's buildEnv root filesystem with /nix/store
# bind-mounted read-only. Provides filesystem and PID isolation
# without requiring Docker or Podman.
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.mkSandboxScript = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Generate a bubblewrap sandbox script for a container.

          Uses the container's `buildEnv` root filesystem with `/nix/store`
          bind-mounted read-only. Provides filesystem and PID isolation
          without requiring Docker or Podman.

          Defaults to an interactive bash shell. Pass arguments to run
          a specific command instead.
        '';
        file = "nix/lib/oci.nix";
        fn = pure.mkSandboxScript;
      };
    };
}
