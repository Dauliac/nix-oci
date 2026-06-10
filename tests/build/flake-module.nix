# Build validation checks — ensures key derivations build.
{ ... }:
{
  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    {
      checks = {
        build-scripts = pkgs.runCommand "build-scripts" {
          buildInputs = [ config.packages.nix-lib-docs ];
        } "touch $out";
      };
    };
}
