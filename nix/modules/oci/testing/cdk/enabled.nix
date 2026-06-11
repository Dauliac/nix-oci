{ lib, ... }:
{
  options.oci.test.cdk.enabled = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable CDK container security auditing globally for all containers.";
    default = false;
  };
}
