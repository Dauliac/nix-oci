{ lib, ... }:
{
  options.license.conftest.enabled = lib.mkEnableOption "SBOM license compliance checking with Conftest";
}
