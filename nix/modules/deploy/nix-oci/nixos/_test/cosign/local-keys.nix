{ lib, ... }:
{
  options.testing.cosign.localKeys = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Generate a local cosign key pair in the test VM.";
  };
}
