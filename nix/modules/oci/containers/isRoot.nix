# Container isRoot option (flake-parts wrapper)
{ ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          imports = [ ./_options/is-root.nix ];
        };
    };
}
