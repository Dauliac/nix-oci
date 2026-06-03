# OCI rootPath option
{ lib, ... }:
{
  options.oci.rootPath = lib.mkOption {
    type = lib.types.path;
    defaultText = lib.literalExpression ''self + "/oci/"'';
    description = "The root path to store the Nix OCI resources.";
  };
}
