# Example: Sandbox-friendly container with starship prompt
#
# Demonstrates the sandbox with home-manager integration.
# The internal HM defaults automatically provide:
#   - bash with history + aliases (ll, la, l)
#   - starship prompt with container-aware format
#   - sensible TERM variable
#
# Run: nix run .#oci-sandbox-sandboxStarship
# The starship prompt appears automatically because:
#   1. Internal HM defaults bake starship init into ~/.bashrc
#   2. The sandbox sets HOME and bind-mounts the home directory
#   3. bash sources .bashrc → starship renders
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
            package = pkgs.curl;
            dependencies = with pkgs; [
              coreutils
              git
            ];

            nixosConfig.modules = [ ];
          };

          homeManager = {
            flake = inputs.home-manager;
            # The internal defaults already provide bash + starship.
            # Override or extend here:
            modules = [
              (
                { ... }:
                {
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
}
