{
  config,
  lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    mkEnableOption
    types
    ;
in
{
  options = {
    oci = {
      compliance = mkOption {
        default = { };
        description = "Configuration for CIS compliance checking in container images.";
        type = types.submodule {
          options = {
            trivy = mkOption {
              description = "Configuration for CIS compliance checking using Trivy.";
              default = { };
              type = types.submodule {
                options = {
                  enabled = mkEnableOption "CIS compliance checking with Trivy";
                  spec = mkOption {
                    type = types.str;
                    description = "The compliance spec to check against. See `trivy image --help` for built-in specs.";
                    default = "docker-cis-1.6.0";
                    example = "docker-cis-1.6.0";
                  };
                  report = mkOption {
                    type = types.enum [
                      "all"
                      "summary"
                    ];
                    description = "Compliance report format: `all` for detailed results or `summary` for a condensed overview.";
                    default = "summary";
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
