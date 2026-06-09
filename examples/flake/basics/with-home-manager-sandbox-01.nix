# Example: Sandbox-friendly container with starship prompt
#
# A non-root container with home-manager configuring bash + starship.
# The sandbox (`nix run .#oci-sandbox-sandboxStarship`) drops into an
# interactive bash shell where starship is visible because:
#   1. home-manager bakes .bashrc (with `eval "$(starship init bash)"`)
#      into the container's /home/<user>/ via the buildEnv
#   2. The sandbox sets HOME=/home/<user> and bind-mounts the home dir
#   3. bash sources .bashrc on startup → starship prompt appears
#
# NOTE: requires home-manager flake input.
{ inputs, ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          sandboxStarship = {
            isRoot = false;
            user = "dev";
            package = pkgs.bashInteractive;
            dependencies = with pkgs; [
              coreutils
              git
              curl
            ];
            entrypoint = [
              "${pkgs.bashInteractive}/bin/bash"
            ];

            nixosConfig = {
              enable = true;
              modules = [ ];
            };

            homeConfig = {
              enable = true;
              homeManagerFlake = inputs.home-manager;
              modules = [
                (
                  { ... }:
                  {
                    programs.bash = {
                      enable = true;
                      shellAliases = {
                        ll = "ls -la";
                      };
                    };

                    programs.starship = {
                      enable = true;
                      enableBashIntegration = true;
                      settings = {
                        add_newline = false;
                        character = {
                          success_symbol = "[➜](bold green)";
                          error_symbol = "[✗](bold red)";
                        };
                        container = {
                          format = "[$symbol]($style) ";
                          symbol = "📦";
                        };
                      };
                    };

                    programs.git = {
                      enable = true;
                      userName = "dev";
                      userEmail = "dev@container";
                    };
                  }
                )
              ];
            };
          };
        };
      };
  };
}
