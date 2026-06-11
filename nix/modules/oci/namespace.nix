# Mount all flake-level oci.* options as a types.submoduleWith.
# Discovered by import-tree. Option files in _oci/ define options
# at relative paths (e.g. options.cve.trivy.enabled) and the
# submodule provides the oci.* namespace prefix.
#
# Uses the pure discoverModules function (not nix-lib) because
# option type definitions cannot reference config.* values.
{ lib, ... }:
let
  discoverModules = import ../../lib/discoverModules.nix { inherit lib; };
in
{
  options.oci = lib.mkOption {
    type = lib.types.submoduleWith {
      modules = discoverModules ./_oci;
    };
    default = { };
    description = "OCI container image configuration.";
  };
}
