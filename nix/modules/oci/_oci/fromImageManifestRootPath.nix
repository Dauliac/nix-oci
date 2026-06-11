{ lib, ... }:
{
  options.fromImageManifestRootPath = lib.mkOption {
    type = lib.types.path;
    defaultText = lib.literalExpression ''config.rootPath + "/pulledManifestsLocks/"'';
    description = "The root path to store the pulled OCI image manifest JSON lockfiles.";
  };
}
