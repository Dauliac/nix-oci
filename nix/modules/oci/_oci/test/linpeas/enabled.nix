{ lib, ... }:
{
  options.test.linpeas.enabled = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable linPEAS privilege escalation auditing globally for all containers.";
    default = false;
  };
}
