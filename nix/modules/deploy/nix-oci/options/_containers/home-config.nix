# Deploy: home-manager configuration options for containers.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.homeConfig = {
    homeManagerFlake = mkOption {
      type = types.nullOr types.unspecified;
      description = ''
        The home-manager flake input. When set, enables home-manager
        integration for this container.
        Example: homeConfig.homeManagerFlake = inputs.home-manager;
      '';
      default = null;
    };

    modules = mkOption {
      type = types.listOf types.unspecified;
      description = ''
        Home-manager modules for this container user's home directory.
        These configure dotfiles, shell, git, editor, etc.
        Requires homeConfig.homeManagerFlake to be set.
      '';
      default = [ ];
    };
  };
}
