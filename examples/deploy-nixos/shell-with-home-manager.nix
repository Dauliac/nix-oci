# Example: NixOS deploy -- shell container with home-manager dotfiles.
#
# Demonstrates homeConfig in deploy: bakes bash aliases and starship
# prompt into a non-root container. The home-manager flake input must
# be provided by the consumer (e.g. via _module.args or specialArgs).
{
  pkgs,
  home-manager-flake,
  ...
}:
{
  oci = {
    enable = true;
    backend = "podman";
    containers.dev-shell = {
      package = pkgs.bashInteractive;
      isRoot = false;
      user = "dev";
      dependencies = with pkgs; [
        coreutils
        curl
      ];
      nixosConfig.modules = [ ];
      homeManager = {
        flake = home-manager-flake;
        modules = [
          {
            programs.bash = {
              enable = true;
              shellAliases = {
                ll = "ls -la";
                gs = "git status";
              };
            };
          }
        ];
      };
      autoStart = true;
      entrypoint = [
        "${pkgs.bashInteractive}/bin/bash"
        "-c"
        "exec sleep infinity"
      ];
    };
  };
}
