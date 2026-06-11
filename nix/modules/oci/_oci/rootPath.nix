{ lib, ... }:
{
  options.rootPath = lib.mkOption {
    type = lib.types.path;
    defaultText = lib.literalExpression ''self + "/oci/"'';
    description = "The root path to store the Nix OCI resources.";
  };
}
