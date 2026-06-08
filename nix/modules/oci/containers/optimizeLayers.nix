# Container optimizeLayers option (flake-parts wrapper)
{ ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          imports = [ ./_options/optimize-layers.nix ];
        };
    };
}
