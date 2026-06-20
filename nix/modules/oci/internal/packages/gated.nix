# Gated OCI images: raw images wrapped with check dependencies.
#
# For each container, collects all enabled checks (dive, dockle, conftest,
# credentials-leak, sbom) and creates a gated image via mkGatedImage.
# The gated image is the raw image + a .gate derivation that depends on
# all checks. Building the gate forces all checks to pass.
#
# The gated images replace raw images in prefixedOCIs (packages output).
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
  inherit (lib) mkOption types attrsets;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        config,
        pkgs,
        ...
      }:
      let
        ociLib = config.lib.oci or { };
      in
      {
        options.oci.internal = {
          gatedOCIs = mkOption {
            description = "OCI images gated by their enabled checks.";
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: rawImage:
              let
                containerConfig = config.oci.containers.${containerId};

                # Collect all enabled check derivations for this container.
                checks =
                  lib.optional (
                    config.oci.internal.diveChecks ? ${containerId}
                  ) config.oci.internal.diveChecks.${containerId}
                  ++ lib.optional (
                    config.oci.internal.lintDockleChecks ? ${containerId}
                  ) config.oci.internal.lintDockleChecks.${containerId}
                  ++ lib.optional (
                    config.oci.internal.policyConftestChecks ? ${containerId}
                  ) config.oci.internal.policyConftestChecks.${containerId}
                  ++ lib.optional (
                    (config.oci.internal.credentialsLeakTrivyChecks or { }) ? ${containerId}
                  ) config.oci.internal.credentialsLeakTrivyChecks.${containerId}
                  ++ lib.optional (
                    (config.oci.internal.sbomSyftChecks or { }) ? ${containerId}
                  ) config.oci.internal.sbomSyftChecks.${containerId};
              in
              ociLib.mkGatedImage {
                inherit pkgs rawImage checks;
                name = containerId;
              }
            ) config.oci.internal.OCIs;
          };

          gatedFlavourOCIs = mkOption {
            description = "Flavour OCI images gated by their enabled checks.";
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: rawImage:
              ociLib.mkGatedImage {
                inherit pkgs rawImage;
                # Flavour images inherit checks from their base container.
                # For now, no additional checks on flavours.
                checks = [ ];
                name = containerId;
              }
            ) config.oci.internal.flavourOCIs;
          };

          # Override prefixedOCIs to use gated images.
          gatedPrefixedOCIs = mkOption {
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-";
              set = config.oci.internal.gatedOCIs // config.oci.internal.gatedFlavourOCIs;
            };
          };
        };
      }
    );
  };
}
