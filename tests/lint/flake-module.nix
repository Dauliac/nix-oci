# Lint checks — formatting and prose quality.
#
# treefmt is handled separately by nix/treefmt.nix (already wired).
# This module adds additional linters that aren't part of treefmt.
{ ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      checks = {
        lint-vale =
          pkgs.runCommandLocal "lint-vale"
            {
              nativeBuildInputs = [ pkgs.vale ];
              src = lib.fileset.toSource {
                root = ../..;
                fileset = lib.fileset.unions [
                  ../../docs/content
                  ../../.vale.ini
                ];
              };
            }
            ''
              cd "$src"
              vale sync 2>&1 || true
              vale docs/content/
              mkdir -p "$out"
            '';
      };
    };
}
