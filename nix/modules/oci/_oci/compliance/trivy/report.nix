{ lib, ... }:
{
  options.compliance.trivy.report = lib.mkOption {
    type = lib.types.enum [
      "all"
      "summary"
    ];
    description = "Compliance report format: `all` for detailed results or `summary` for a condensed overview.";
    default = "summary";
  };
}
