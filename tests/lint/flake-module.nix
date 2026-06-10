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
    let
      # Vale style packages fetched from GitHub releases.
      # Update versions here when bumping vale styles.
      valeStyles = {
        Google = pkgs.fetchzip {
          url = "https://github.com/errata-ai/Google/releases/download/v0.6.3/Google.zip";
          hash = "sha256-ScbKdC7kaPB9KM6erZ2COsSwSYracreBBX1HNQUEIgA=";
          stripRoot = false;
        };
        write-good = pkgs.fetchzip {
          url = "https://github.com/errata-ai/write-good/releases/download/v0.4.1/write-good.zip";
          hash = "sha256-XhvZtirGg9Vl/i73HMyZpK2iSoQoXv8OS7ckryveIdU=";
          stripRoot = false;
        };
        proselint = pkgs.fetchzip {
          url = "https://github.com/errata-ai/proselint/releases/download/v0.3.4/proselint.zip";
          hash = "sha256-aazHkxWMFySHJZz2Er3PVXQ9/yWUAxxfiltkv8X6x30=";
          stripRoot = false;
        };
        alex = pkgs.fetchzip {
          url = "https://github.com/errata-ai/alex/releases/download/v0.2.3/alex.zip";
          hash = "sha256-YvNfhjCg437wDMxnOqu9xTKq82KZfQt9HvCpoDfwsL4=";
          stripRoot = false;
        };
      };
    in
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
                  ../../.vale/styles/config
                ];
              };
            }
            ''
              cp -r "$src" work
              chmod -R u+w work

              # Inject fetched style packages into .vale/styles/
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (name: drv: "cp -r ${drv} work/.vale/styles/${name}") valeStyles
              )}

              cd work
              vale docs/content/
              mkdir -p "$out"
            '';
      };
    };
}
