# Shared test helpers for nix-oci.
#
# Provides reusable builders so each test category (unit, vm, e2e)
# can declare checks with minimal boilerplate.
{
  pkgs,
  lib,
}:
{
  # Wrap a NixOS VM test with the standard per-node defaults from
  # `nix/modules/oci/testing/_vm-defaults/default.nix` (virtualisation
  # sizing, boot-speed tweaks, disabled services). Accepts the same args
  # as `pkgs.testers.runNixOSTest`.
  #
  # Each node automatically imports the shared defaults; callers that
  # want to override any knob do so via standard module composition
  # inside the node (e.g. `virtualisation.cores = lib.mkForce 4;`).
  # The `_app-vm` module layers per-container smoke sizing on top for
  # the `bdd-app-<name>` VMs.
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
          # NixOS test default is 1h. The app-tests aggregate VM used to
          # load ~20 example images sequentially (1-3 min each on GHA).
          # The per-container `bdd-app-<name>` split cut this to one
          # image per VM, so 3h is now vast headroom, kept to be safe
          # against the aggregate ever being revived.
          globalTimeout = 3 * 3600;
          nodes = lib.mapAttrs (
            _: nodeCfg:
            {
              pkgs,
              lib,
              ...
            }:
            {
              imports = [
                ../nix/modules/oci/testing/_vm-defaults
              ]
              ++ (lib.optional (!builtins.isFunction nodeCfg) nodeCfg)
              ++ (lib.optional (builtins.isFunction nodeCfg) (nodeCfg {
                inherit pkgs lib;
              }));
            }
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
