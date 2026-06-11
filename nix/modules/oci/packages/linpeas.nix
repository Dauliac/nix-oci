# OCI packages - linpeas
#
# linPEAS (Linux Privilege Escalation Awesome Script) from PEASS-ng.
# Pure sh script for comprehensive privilege escalation enumeration.
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
      options.oci.packages.linpeas = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for linpeas.";
        default = pkgs.stdenvNoCC.mkDerivation {
          pname = "linpeas";
          version = "20260604";
          src = pkgs.fetchurl {
            url = "https://github.com/peass-ng/PEASS-ng/releases/download/20260604-085abf96/linpeas.sh";
            hash = "sha256-9TLMXlNztzaiabcx0WYR1ydzuZHn76gS4yUyCYw2+S0=";
          };
          dontUnpack = true;
          installPhase = ''
            install -Dm755 $src $out/bin/linpeas.sh
          '';
          meta = {
            description = "Linux Privilege Escalation Awesome Script (PEASS-ng)";
            homepage = "https://github.com/peass-ng/PEASS-ng";
            license = lib.licenses.mit;
            platforms = lib.platforms.linux;
            mainProgram = "linpeas.sh";
          };
        };
        defaultText = lib.literalExpression "linpeas 20260604";
        example = defaultText;
      };
    }
  );
}
