# Container homeConfig.modules option
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.homeConfig.modules = mkOption {
            type = types.listOf types.unspecified;
            description = ''
              Home-manager modules for this container user's home directory.
              These configure dotfiles, shell, git, editor, etc.
              Requires homeConfig.homeManagerFlake to be set.
            '';
            default = [ ];
          };
        };
    };
}
