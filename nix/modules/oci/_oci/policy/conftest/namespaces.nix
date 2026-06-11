{ lib, ... }:
{
  options.policy.conftest.namespaces = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "Rego namespaces to check. Each namespace maps to a `package` declaration in the policy files.";
    default = [ "main" ];
    example = [ "main" "custom" ];
  };
}
