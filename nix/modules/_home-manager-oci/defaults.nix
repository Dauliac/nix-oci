# Home-manager guard & defaults module for OCI container environments.
#
# Imported into the NixOS eval's home-manager.users.${user}.imports.
# Provides an oci.container.* namespace that mirrors the nixos-oci pattern:
# - Input bridge: receives container identity from eval-container.nix
# - Guards: assertions to prevent misconfiguration
# - Defaults: mkDefault for shell/terminal + mkDefault false for bloat
#
# Design decisions:
# - systemd.user.services: NOT asserted against. WM modules (i3, sway)
#   generate units as a side-effect of config generation. The units are
#   harmless (no systemd user session), and the config files are valuable
#   for VNC/desktop containers (Kasm, Webtop, Neko pattern).
# - WM config / GUI programs: ALLOWED. Legitimate for VNC desktops,
#   Cypress/Playwright/Selenium CI containers.
# - Expensive defaults: disabled via mkDefault false. Users who need them
#   (e.g. fontconfig for a desktop container) can override.
{
  config,
  lib,
  ...
}:
{
  # --- oci.container namespace (input bridge from nixos-oci eval) ---
  options.oci.container = {
    user = lib.mkOption {
      type = lib.types.str;
      description = ''
        Container app user name. Set by nixos-oci eval.
        nix-oci containers have exactly one app user; home-manager
        must configure this user only.
      '';
    };

    homeDirectory = lib.mkOption {
      type = lib.types.str;
      description = ''
        Container user home directory. Set by nixos-oci eval.
        Derived from oci.container.user: /root for root, /home/<user> otherwise.
      '';
    };

    name = lib.mkOption {
      type = lib.types.str;
      description = ''
        Container name (attribute name from oci.containers.<name>).
        Available for prompt customization and metadata.
      '';
    };
  };

  config = {
    # --- Bind HM identity from oci.container (source of truth) ---
    home.username = lib.mkDefault config.oci.container.user;
    home.homeDirectory = lib.mkDefault config.oci.container.homeDirectory;

    # --- Guard: HM user must match nixos-oci declared user ---
    assertions = [
      {
        assertion = config.home.username == config.oci.container.user;
        message = ''
          home.username "${config.home.username}" does not match the
          container user "${config.oci.container.user}".
          nix-oci containers have a single app user declared by nixos-oci.
          Do not override home.username in homeConfig.modules.
        '';
      }
      {
        assertion = config.home.homeDirectory == config.oci.container.homeDirectory;
        message = ''
          home.homeDirectory "${config.home.homeDirectory}" does not match
          the container home "${config.oci.container.homeDirectory}".
          Do not override home.homeDirectory in homeConfig.modules.
        '';
      }
    ];

    # --- Shell & terminal (primary HM value in containers) ---
    programs.bash = {
      enable = lib.mkDefault true;
      historySize = lib.mkDefault 10000;
      historyFileSize = lib.mkDefault 100000;
      shellAliases = lib.mkDefault {
        ll = "ls -la";
        la = "ls -A";
        l = "ls -CF";
      };
    };

    programs.starship = {
      enable = lib.mkDefault true;
      enableBashIntegration = lib.mkDefault true;
      settings = {
        add_newline = lib.mkDefault false;
        format = lib.mkDefault "$username$hostname$directory$git_branch$git_status$nix_shell$container$character";
        character = {
          success_symbol = lib.mkDefault "[➜](bold green)";
          error_symbol = lib.mkDefault "[✗](bold red)";
        };
        container = {
          format = lib.mkDefault "[$symbol \\($name\\)]($style) ";
          symbol = lib.mkDefault "⬡";
          style = lib.mkDefault "bold dimmed blue";
        };
        directory = {
          truncation_length = lib.mkDefault 3;
          truncate_to_repo = lib.mkDefault false;
        };
        username = {
          show_always = lib.mkDefault true;
          format = lib.mkDefault "[$user]($style)@";
        };
        hostname = {
          ssh_only = lib.mkDefault false;
          format = lib.mkDefault "[$hostname]($style):";
        };
        nix_shell = {
          symbol = lib.mkDefault "❄️ ";
        };
      };
    };

    home.sessionVariables = {
      TERM = lib.mkDefault "xterm-256color";
    };

    # --- Disable expensive/useless defaults for containers ---
    # shared-mime-info: ~3MB closure, useless without a desktop
    xdg.mime.enable = lib.mkDefault false;
    # /usr/share/{applications,icons,fonts} from host -- not relevant
    targets.genericLinux.enable = lib.mkDefault false;
    # fontconfig: pulls freetype/fontconfig -- only useful for GUI containers
    fonts.fontconfig.enable = lib.mkDefault false;
    # Suppress home-manager news during eval
    news.display = lib.mkDefault "silent";
  };
}
