# Shared: home-manager integration.
#
# Provides home-manager configuration for the container user's
# home directory (dotfiles, shell, git, editor, etc.).
{ lib, ... }:
{
  options.homeManager = {
    flake = lib.mkOption {
      type = lib.types.nullOr lib.types.unspecified;
      default = null;
      description = ''
        The home-manager flake input. When set, enables home-manager
        integration for this container.

        Example:
        ```nix
        oci.containers.dev = {
          homeManager.flake = inputs.home-manager;
          homeManager.modules = [{ home.packages = [ pkgs.vim ]; }];
        };
        ```
      '';
      example = "inputs.home-manager";
    };
    modules = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
      default = [ ];
      description = ''
        Home-manager modules for the container user's home directory.

        These configure dotfiles, shell, git, editor, etc. Requires
        `homeManager.flake` to be set.
      '';
    };
  };
}
