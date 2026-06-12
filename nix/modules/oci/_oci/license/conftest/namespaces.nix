{ lib, ... }:
{
  options.license.conftest.namespaces = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "Rego namespaces to check. Each namespace maps to a `package` declaration in the license policy files.";
    default = [ "license" ];
    example = [
      "license"
      "custom_license"
    ];
  };
}
