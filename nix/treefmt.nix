{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];
  config.perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      treefmt = {
        settings.global.excludes = [
          "docs/flake-parts-website/**"
        ];
        programs = {
          alejandra.enable = true;
          jsonfmt.enable = true;
          nixfmt.enable = true;
          shellcheck.enable = true;
          shfmt.enable = true;
          toml-sort.enable = true;
          typos.enable = true;
          yamlfmt.enable = true;
        };
      };
    };
}
