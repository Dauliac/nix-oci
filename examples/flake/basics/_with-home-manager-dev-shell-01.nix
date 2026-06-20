# Example: Developer shell container with home-manager dotfiles
#
# A non-root container with home-manager configuring:
# - zsh as default shell
# - starship prompt
# - neovim with yaml-language-server (for editing k8s manifests, etc.)
# - git, curl, jq as dev tools
#
# This shows how to use homeConfig to bake dotfiles into OCI images,
# creating portable, reproducible dev environments.
#
# NOTE: requires home-manager flake input. In the nix-oci dev partition
# it's available via dev/flake.nix inputs.
{ inputs, ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          devShell = {
            isRoot = false;
            user = "dev";
            package = pkgs.zsh;
            dependencies = with pkgs; [
              bashInteractive
              coreutils
              git
              curl
              jq
              ripgrep
              fd
            ];
            entrypoint = [
              "${pkgs.zsh}/bin/zsh"
            ];
            labels = {
              "org.opencontainers.image.title" = "dev-shell";
              "org.opencontainers.image.description" = "Developer shell with zsh, starship, neovim (yaml LSP)";
            };

            # NixOS module: provides /etc, users, shadow files
            nixosConfig.modules = [
                (
                  { pkgs, ... }:
                  {
                    environment.systemPackages = with pkgs; [
                      neovim
                      yaml-language-server
                    ];
                  }
                )
              ];

            # Home-manager: dotfiles baked into the image
            homeManager = {
              flake = inputs.home-manager;
              modules = [
                (
                  { pkgs, ... }:
                  {
                    programs.zsh = {
                      enable = true;
                      autosuggestion.enable = true;
                      syntaxHighlighting.enable = true;
                      shellAliases = {
                        ll = "ls -la";
                        k = "kubectl";
                        vim = "nvim";
                      };
                    };

                    programs.starship = {
                      enable = true;
                      enableZshIntegration = true;
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

                    programs.neovim = {
                      enable = true;
                      defaultEditor = true;
                      extraConfig = ''
                        set number
                        set relativenumber
                        set expandtab
                        set shiftwidth = 2
                      '';
                      extraPackages = [ pkgs.yaml-language-server ];
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
