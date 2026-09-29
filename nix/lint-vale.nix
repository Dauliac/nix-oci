{
  config.perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      repoRoot = ../.;
      styles = config.oci.packages.vale-styles;

      # Merge the fetched packs with the repo's versioned vocab/config into
      # a single StylesPath tree.
      stylesWithConfig = pkgs.runCommand "vale-styles-with-config" { } ''
        mkdir -p $out
        for d in ${styles}/*; do
          ln -s "$d" "$out/$(basename "$d")"
        done
        mkdir -p $out/config
        cp -r ${repoRoot + "/.vale/styles/config"}/* $out/config/
      '';

      lintSrc = lib.fileset.toSource {
        root = repoRoot;
        fileset = lib.fileset.unions [
          (repoRoot + "/.vale.ini")
          (lib.fileset.maybeMissing (repoRoot + "/README.md"))
          (lib.fileset.maybeMissing (repoRoot + "/CHANGELOG.md"))
          (lib.fileset.maybeMissing (repoRoot + "/CONTRIBUTING.md"))
          (lib.fileset.fileFilter (f: f.hasExt "md") (repoRoot + "/docs/content"))
          (lib.fileset.fileFilter (f: f.hasExt "md") (repoRoot + "/openspec"))
          (lib.fileset.maybeMissing (repoRoot + "/plan"))
        ];
      };
    in
    {
      checks.lint-vale = pkgs.runCommand "lint-vale"
        {
          nativeBuildInputs = [ pkgs.vale ];
        }
        ''
          cp -r ${lintSrc}/. ./src
          chmod -R +w ./src
          cd ./src
          # Point StylesPath at the hermetic tree (packs + vocab).
          sed -i "s|^StylesPath =.*|StylesPath = ${stylesWithConfig}|" .vale.ini
          vale --no-exit --config=.vale.ini --output=line . || true
          vale --config=.vale.ini --minAlertLevel=error .
          touch $out
        '';
    };
}
