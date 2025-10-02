{ ... }:
{
  config = {
    perSystem =
      {
        pkgs,
        config,
        ...
      }:
      {
        checks = {
          buildScripts = pkgs.runCommand "build-scripts" {
            buildInputs = [ config.packages.oci-updatePulledManifestsLocks ];
          } "touch $out";
          endToEnd =
            pkgs.runCommand "build-scripts"
              {
                buildInputs = with pkgs; [
                  bats
                  go-task
                  nix
                ];
              }
              ''
                task test --verbose --output prefixed
              '';
        };
      };
  };
}
