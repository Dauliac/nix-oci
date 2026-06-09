# Deploy: nixosConfig options + NixOS eval for containers.
#
# Mirrors the flake-parts nixosConfig/ modules but in deploy submodule scope.
# Delegates to the shared evalContainerNixos function so both contexts
# use the exact same eval pipeline.
{
  name,
  config,
  lib,
  pkgs,
  ociNixOSModules,
  ...
}:
let
  inherit (lib) mkOption types;
  evalContainerLib = import ../../../../../lib/eval-container.nix { inherit lib; };
  nixosCfg = config.nixosConfig;
  enabled = nixosCfg.mainService != null || nixosCfg.modules != [ ];

  result = evalContainerLib.evalContainerNixos {
    inherit pkgs ociNixOSModules;
    containerName = name;
    containerConfig = config;
    nixosModules = nixosCfg.modules;
    mainService = nixosCfg.mainService;
    homeManagerFlake = config.homeConfig.homeManagerFlake or null;
    homeModules = config.homeConfig.modules or [ ];
  };
in
{
  options.nixosConfig = {
    modules = mkOption {
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

    mainService = mkOption {
      type = types.nullOr types.str;
      description = ''
        The NixOS service that this container runs.

        When set, the container's package is auto-derived from the service
        module's package option, and an entrypoint wrapper script is
        generated from the service's systemd unit (preStart, ExecStartPre,
        ExecStart, directory creation).

        Cannot be set together with `package` - they are mutually exclusive
        sources for the container's main program.
      '';
      default = null;
      example = "nginx";
    };

    eval = mkOption {
      type = types.nullOr types.unspecified;
      internal = true;
      readOnly = true;
      description = "The fully evaluated NixOS configuration for this container.";
      default = if enabled then result.evalResult else null;
    };
  };

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

  config = lib.mkIf enabled {
    # Auto-derive user from eval (service package → package → containerName).
    user = lib.mkDefault result.containerUser;
  };
}
