{ lib, ... }:
{
  options.license.conftest.policyDir = lib.mkOption {
    type = lib.types.path;
    description = ''
      Path to a directory containing Rego policy files for license checking.

      Policies receive a CycloneDX SBOM JSON as input and should define
      `deny` or `warn` rules in the `license` package. nix-oci ships
      built-in policies that reject common forbidden licenses (AGPL, SSPL)
      and warn on copyleft licenses (GPL, LGPL).
    '';
    default = ../../../security/license/conftest/policies;
    defaultText = lib.literalExpression "built-in nix-oci license policies";
  };
}
