# OCI packages - amicontained
#
# Static binary fetched from GitHub releases. Not in nixpkgs.
# amicontained is a container introspection tool that detects
# runtime, capabilities, seccomp profile, and namespaces.
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.amicontained = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for amicontained.";
        default =
          let
            # Only x86_64-linux has a published release binary.
            # aarch64 users can override oci.packages.amicontained with
            # a locally-built version.
            src = {
              url = "https://github.com/genuinetools/amicontained/releases/download/v0.4.9/amicontained-linux-amd64";
              hash = "sha256-2MSeLPRO6WaCGazQku2WH8GqQgpuA24IItejEDN3bJ8=";
            };
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "amicontained";
            version = "0.4.9";
            src = pkgs.fetchurl {
              inherit (src) url hash;
            };
            dontUnpack = true;
            installPhase = ''
              install -Dm755 $src $out/bin/amicontained
            '';
            meta = {
              description = "Container introspection tool";
              homepage = "https://github.com/genuinetools/amicontained";
              license = lib.licenses.mit;
              platforms = [ "x86_64-linux" ];
              mainProgram = "amicontained";
            };
          };
        defaultText = lib.literalExpression "amicontained v0.4.9 static binary";
        example = defaultText;
      };
    }
  );
}
