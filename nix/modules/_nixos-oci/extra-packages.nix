# Unified extra packages option.
#
# Any _nixos-oci module can append packages here. These are included in the
# container root filesystem alongside cfg.package and cfg.dependencies.
#
# Replaces the scattered _output.{performance,gpu}.extraDeps and
# _output.adapterPackages with a single composable list.
#
# Examples:
#   - performance/outputs.nix adds the allocator library
#   - gpu/outputs.nix adds CUDA runtime libraries
#   - nix-support/outputs.nix adds nix, bash, coreutils
#   - service adapters add healthcheck tools (curl, dig, redis-cli)
{ lib, ... }:
{
  options.oci.container.extraPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = ''
      Additional packages included in the container root filesystem.

      Any _nixos-oci module can append to this list. The root-filesystem
      collector merges all contributions into the final buildEnv.

      This replaces the previous pattern of scattered
      `_output.{performance,gpu}.extraDeps` and `_output.adapterPackages`.
    '';
  };
}
