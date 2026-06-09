# Container initializeNixDatabase option (flake-parts wrapper)
{ ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          imports = [ ./_options/initialize-nix-database.nix ];
        };
    };
}
