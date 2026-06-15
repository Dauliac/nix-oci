# Shared test helpers for nix-oci.
#
# Provides reusable builders so each test category (unit, vm, e2e)
# can declare checks with minimal boilerplate.
{
  pkgs,
  lib,
}:
{
  # Wrap a NixOS VM test with standard resource defaults.
  # Accepts the same args as pkgs.testers.runNixOSTest, but injects
  # sensible virtualisation defaults (cores, memory, disk, podman).
  mkVMTest =
    {
      name,
      nodes,
      testScript,
      ...
    }@args:
    pkgs.testers.runNixOSTest (
      lib.recursiveUpdate
        {
          inherit name testScript;
          nodes = lib.mapAttrs (
            _: nodeCfg:
            {
              pkgs,
              lib,
              ...
            }:
            lib.recursiveUpdate {
              virtualisation = {
                cores = 8;
                memorySize = 4096;
                diskSize = 8192;
              };
              documentation.enable = false;
            } (if builtins.isFunction nodeCfg then nodeCfg { inherit pkgs lib; } else nodeCfg)
          ) nodes;
        }
        (
          builtins.removeAttrs args [
            "name"
            "nodes"
            "testScript"
          ]
        )
    );
}
