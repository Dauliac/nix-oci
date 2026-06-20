# Top-level flake-parts oci.* options.
#
# Only flake-scoped control flags live here.
# All per-container options live in _oci/ (mounted by perContainer.nix).
# Shared defaults are applied via oci.perContainer, not via a bridge.
{ lib, ... }:
{
  options.oci = {
    enabled = lib.mkEnableOption "Enable the OCI module.";

    enableFlakeOutputs = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to automatically expose OCI apps, packages, and checks as flake outputs.";
      default = true;
      example = false;
    };

    enableDevShell = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to enable the flake development shell.";
      default = false;
    };
  };
}
