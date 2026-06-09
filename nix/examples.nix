{ inputs, ... }:
{
  imports = [ (inputs.import-tree ../examples/flake) ];
  config.oci.fromImageManifestRootPath = ../examples/flake + "/";
}
