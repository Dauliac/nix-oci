{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      { config, ... }:
      {
        options.oci.internal = {
          packages = mkOption {
            type = types.listOf types.package;
            internal = true;
            readOnly = true;
            default = with config.oci.packages; [
              skopeo
              containerStructureTest
              podman
              grype
              syft
              trivy
              dive
              dgoss
              skaffold
            ];
          };
        };
      }
    );
  };
}
