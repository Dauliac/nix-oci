{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.oci.signing.cosign.verify = mkOption {
    type = types.bool;
    description = "Whether to verify the signature immediately after signing.";
    default = true;
  };
}
