# Container layerStrategy option (flake-parts wrapper)
{ ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          imports = [ ./_options/layer-strategy.nix ];
        };
    };
}
