{ inputs, ... }:
{
  imports = [ (inputs.import-tree ../examples/build) ];
  config.oci.fromImageManifestRootPath = ../examples/build + "/";
}
