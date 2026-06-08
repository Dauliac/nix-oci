# Container labels option (flake-parts wrapper)
{ ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          imports = [ ./_options/labels.nix ];
        };
    };
}
