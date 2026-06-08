# Container nixosConfig.modules option
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
          options.nixosConfig.modules = mkOption {
            type = types.listOf types.unspecified;
            description = ''
              NixOS modules to evaluate for this container.

              These modules are evaluated with `boot.isContainer = true` and
              the resulting config files, packages, users/groups, and entrypoint
              are extracted into the container image.

              Only one service should be enabled per container (no init system).
              Use `nixosConfig.mainService` to designate which service this
              container runs.
            '';
            default = [ ];
            example = lib.literalExpression ''
              [
                ({ pkgs, ... }: {
                  services.nginx = {
                    enable = true;
                    virtualHosts."app".root = "/var/www";
                  };
                })
              ]
            '';
          };
        };
    };
}
