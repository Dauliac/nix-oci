{ inputs, ... }:
{
  imports = [ (inputs.import-tree ../examples) ];
  config.oci.fromImageManifestRootPath = ../examples + "/";
}
