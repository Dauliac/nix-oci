# OCI packages - deepce
#
# DEEPCE (Docker Enumeration, Escalation of Privileges and Container
# Escapes) is a pure sh script for container security assessment.
# Not in nixpkgs.
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.deepce = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for deepce.";
        default = pkgs.stdenvNoCC.mkDerivation {
          pname = "deepce";
          version = "0.1.0";
          src = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/stealthcopter/deepce/main/deepce.sh";
            hash = "sha256-LIMBw+jRLAH2rTnpUT9acBHMqu5+7h9AlRo4t1bTv5g=";
          };
          dontUnpack = true;
          installPhase = ''
            install -Dm755 $src $out/bin/deepce.sh
          '';
          meta = {
            description = "Docker Enumeration, Escalation of Privileges and Container Escapes";
            homepage = "https://github.com/stealthcopter/deepce";
            license = lib.licenses.mit;
            platforms = lib.platforms.linux;
            mainProgram = "deepce.sh";
          };
        };
        defaultText = lib.literalExpression "deepce v0.1.0";
        example = defaultText;
      };
    }
  );
}
