# OCI packages - cdk
#
# CDK (Container penetration toolkit) is a static Go binary for
# K8s/Docker security auditing and breakout detection. Not in nixpkgs.
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.cdk = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for CDK.";
        default =
          let
            srcs = {
              x86_64-linux = {
                url = "https://github.com/cdk-team/CDK/releases/download/v1.5.4/cdk_linux_amd64";
                hash = "sha256-IPLl5+dJU9N8WYa3UdjS4M3SHSJ139/CGl9Pi0o3d28=";
              };
              aarch64-linux = {
                url = "https://github.com/cdk-team/CDK/releases/download/v1.5.4/cdk_linux_arm64";
                hash = "sha256-tvt0z0vPGtBrwEJK9IHf+W6YzwaAPUUMTZo7Yhtjlm4=";
              };
            };
            src = srcs.${pkgs.stdenv.hostPlatform.system} or (throw "cdk: unsupported platform ${pkgs.stdenv.hostPlatform.system}");
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "cdk";
            version = "1.5.4";
            src = pkgs.fetchurl {
              inherit (src) url hash;
            };
            dontUnpack = true;
            installPhase = ''
              install -Dm755 $src $out/bin/cdk
            '';
            meta = {
              description = "Container penetration toolkit for K8s/Docker security auditing";
              homepage = "https://github.com/cdk-team/CDK";
              license = lib.licenses.gpl2Only;
              platforms = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              mainProgram = "cdk";
            };
          };
        defaultText = lib.literalExpression "cdk v1.5.4 static binary";
        example = defaultText;
      };
    }
  );
}
