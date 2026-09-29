{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.vale-styles = lib.mkOption {
        type = lib.types.package;
        description = "Vale style packs (Google, Microsoft, RedHat, write-good, proselint, alex, Joblint, Readability) as a single StylesPath derivation.";
        default =
          let
            fetchStyle =
              name:
              {
                owner,
                repo,
                tag,
                zip,
                hash,
              }:
              pkgs.stdenvNoCC.mkDerivation {
                pname = "vale-style-${name}";
                version = tag;
                src = pkgs.fetchzip {
                  url = "https://github.com/${owner}/${repo}/releases/download/${tag}/${zip}";
                  inherit hash;
                };
                dontConfigure = true;
                dontBuild = true;
                installPhase = ''
                  mkdir -p $out/${name}
                  cp -r . $out/${name}/
                '';
              };
            specs = {
              Google = {
                owner = "vale-cli";
                repo = "Google";
                tag = "v0.7.1";
                zip = "Google.zip";
                hash = "sha256-gONA7Y35XneE6YmLAU3ECSkn0e+9ZhlSY2uEsOIlyQI=";
              };
              Microsoft = {
                owner = "vale-cli";
                repo = "Microsoft";
                tag = "v0.15.1";
                zip = "Microsoft.zip";
                hash = "sha256-laEQiPpC30Ie/9//atiY3S1YTpYMPedygcrxl4shEl4=";
              };
              write-good = {
                owner = "vale-cli";
                repo = "write-good";
                tag = "v0.4.1";
                zip = "write-good.zip";
                hash = "sha256-kmmQDA7RetpEqa7ZkLvS8ejMO/DJxCCoh2B78X1WsZY=";
              };
              proselint = {
                owner = "vale-cli";
                repo = "proselint";
                tag = "v0.3.4";
                zip = "proselint.zip";
                hash = "sha256-9zDa0rR5L8FQfd45Z7msiG2z6C6YvRDFTovf2KCCs3E=";
              };
              alex = {
                owner = "vale-cli";
                repo = "alex";
                tag = "v0.2.3";
                zip = "alex.zip";
                hash = "sha256-VOaknDLo3hCdiszQ7gph0ujxLa9BwRvoAoDrkjm6hZw=";
              };
              Joblint = {
                owner = "vale-cli";
                repo = "Joblint";
                tag = "v0.4.1";
                zip = "Joblint.zip";
                hash = "sha256-NjK5oDwBqDd70KBPMTpHuRSqVpfQIChLnAWWzirZB0M=";
              };
              Readability = {
                owner = "vale-cli";
                repo = "readability";
                tag = "v0.2.0";
                zip = "Readability.zip";
                hash = "sha256-iJ+20ZQQ1O1LoAn/fdXg4CE6iPQMhCLjKIAeyO66QoQ=";
              };
              RedHat = {
                owner = "redhat-documentation";
                repo = "vale-at-red-hat";
                tag = "v678";
                zip = "RedHat.zip";
                hash = "sha256-SfZm0dINogAfslQtV/MMO0arMfGe5ckFYL2c8zhonTg=";
              };
            };
            packs = lib.mapAttrs fetchStyle specs;
          in
          pkgs.symlinkJoin {
            name = "vale-styles";
            paths = lib.attrValues packs;
            meta = {
              description = "Bundled Vale style packs for hermetic linting";
              homepage = "https://github.com/errata-ai/packages";
              license = lib.licenses.mit;
            };
          };
        defaultText = lib.literalExpression "symlinkJoin of Google, Microsoft, RedHat, write-good, proselint, alex, Joblint, Readability release zips";
      };
    }
  );
}
