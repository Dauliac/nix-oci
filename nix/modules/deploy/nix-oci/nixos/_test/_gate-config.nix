# NixOS test module: run pure policy gates before container loading.
#
# For each container, generates a systemd oneshot service that runs
# all enabled pure policy runners (conftest, dockle, dive, syft).
# The oci-load-* service depends on the gate service — if the gate
# fails, the container doesn't load.
#
# This makes policy compliance a build-time structural guarantee:
# the VM can't boot with non-compliant containers.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.testing;
  ociCfg = config.oci or { };
  # Import the gate and rego-gen as pure functions (not via config.lib.oci
  # since this is a NixOS module, not a flake-parts module)
in
{
  options.testing.policyGate = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run pure policy gates before container loading in test VM.";
    };

    stamps = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.package);
      default = { };
      internal = true;
      description = ''
        Policy gate stamp derivations per container, injected by
        test-vm.nix from the flake-parts context where config.lib.oci
        is available.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.policyGate.enable && cfg.policyGate.stamps != { }) {
    systemd.services = lib.concatMapAttrs (
      containerId: stamps:
      let
        gateScript = pkgs.writeShellScript "policy-gate-${containerId}" ''
          set -euo pipefail
          echo "Running policy gate for ${containerId}..."
          ${lib.concatMapStrings (stamp: ''
            echo "  Checking ${stamp.name or "stamp"}..."
            : ${stamp}
          '') stamps}
          echo "Policy gate passed for ${containerId}."
        '';
      in
      {
        "oci-gate-${containerId}" = {
          description = "Policy gate for ${containerId}";
          before = [ "oci-load-${containerId}.service" ];
          requiredBy = [ "oci-load-${containerId}.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${gateScript}";
          };
        };
      }
    ) cfg.policyGate.stamps;
  };
}
