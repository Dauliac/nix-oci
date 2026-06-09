# Debug-only home-manager modules
#
# These modules are merged on top of any production homeConfig.modules
# when building the debug variant. Combined with debug.nixosConfig.modules,
# this triggers a second NixOS eval (layer sharing with production is lost).
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.debug.homeConfig.modules = lib.mkOption {
            type = lib.types.listOf lib.types.unspecified;
            description = ''
              Home-manager modules for the debug variant's user environment.
              Merged on top of the production homeConfig.modules (if any).

              When non-empty (and debug.homeConfig.homeManagerFlake is set), a second
              NixOS eval is performed and the debug image will NOT share
              layers with the production image.

              Use this to configure shell, editor, tmux, etc. for debugging.
            '';
            default = [ ];
            example = lib.literalExpression ''
              [
                ({ pkgs, ... }: {
                  programs.tmux.enable = true;
                  programs.htop.enable = true;
                  programs.zsh.enable = true;
                })
              ]
            '';
          };
        };
    };
}
