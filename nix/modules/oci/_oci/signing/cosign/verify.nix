{ lib, ... }:
{
  options.signing.cosign.verify = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to verify the signature immediately after signing.";
    default = true;
  };
}
