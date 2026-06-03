{
  config,
  lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    types
    ;
in
{
  options = {
    oci = {
      sbom = mkOption {
        default = { };
        description = "Configuration for Software Bill of Materials (SBOM) generation in container images.";
        type = types.submodule {
          options = {
            path = mkOption {
              type = types.path;
              description = "Path where SBOM files will be stored.";
              default = cfg.oci.rootPath;
              defaultText = lib.literalExpression "cfg.oci.rootPath";
            };
            # TODO include slim sbom
            syft = mkOption {
              default = { };
              description = "Configuration for SBOM generation using Syft.";
              type = types.submodule {
                options = {
                  enabled = mkOption {
                    type = types.bool;
                    description = "Whether to enable SBOM generation with Syft.";
                    default = false;
                  };
                  config = mkOption {
                    description = "Configuration settings for Syft SBOM generation.";
                    default = { };
                    type = types.submodule {
                      options = {
                        enabled = mkOption {
                          type = types.bool;
                          description = "Whether to enable Syft configuration file generation.";
                          default = false;
                        };
                        rootPath = mkOption {
                          type = types.path;
                          description = "Path where Syft configuration files will be stored.";
                          default = cfg.oci.sbom.path;
                          defaultText = lib.literalExpression "cfg.oci.sbom.path";
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
