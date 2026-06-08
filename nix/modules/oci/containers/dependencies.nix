# Container dependencies option (flake-parts wrapper)
{ ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          imports = [ ./_options/dependencies.nix ];
        };
    };
}
