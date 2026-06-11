{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.oci.compliance.trivy.report = mkOption {
    type = types.enum [
      "all"
      "summary"
    ];
    description = "Compliance report format: `all` for detailed results or `summary` for a condensed overview.";
    default = "summary";
  };
}
