{ inputs, ... }:
{
  imports = [ (inputs.import-tree ../examples/flake) ];
  config.perSystem =
    { ... }:
    {
      oci.fromImageManifestRootPath = ../examples/flake + "/";
    };
}
