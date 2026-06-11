{ lib, ... }:
{
  options.policy.conftest.enabled = lib.mkEnableOption "OCI image config policy checking with Conftest";
}
