{ lib, ... }:
{
  options.compliance.trivy.spec = lib.mkOption {
    type = lib.types.str;
    description = "The compliance spec to check against. See `trivy image --help` for built-in specs.";
    default = "docker-cis-1.6.0";
    example = "docker-cis-1.6.0";
  };
}
