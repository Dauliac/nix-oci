{ lib, ... }:
{
  options.testing.extraPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Extra packages available in the test VM.";
  };
}
