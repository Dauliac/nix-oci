# OCI packages - soci-snapshotter
#
# Static binaries fetched from GitHub releases. Not in nixpkgs.
# Provides both the `soci` CLI (index management) and the
# `soci-snapshotter-grpc` daemon (containerd proxy snapshotter
# for lazy pulling via SOCI v2 indexes).
#
# The NixOS deploy module (deploy/nix-oci/nixos/snapshotter.nix)
# consumes this package to run the gRPC daemon as a systemd service.
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.soci-snapshotter = lib.mkOption rec {
        type = lib.types.package;
        description = "The package providing soci and soci-snapshotter-grpc binaries.";
        default =
          let
            version = "0.14.1";
            srcs = {
              x86_64-linux = {
                url = "https://github.com/awslabs/soci-snapshotter/releases/download/v${version}/soci-snapshotter-${version}-linux-amd64-static.tar.gz";
                hash = "sha256-5wUx32dvdC+W+mp6DDRPHdke1SaXq8R2y2KNUvdW9eo=";
              };
              aarch64-linux = {
                url = "https://github.com/awslabs/soci-snapshotter/releases/download/v${version}/soci-snapshotter-${version}-linux-arm64-static.tar.gz";
                hash = "sha256-T3pAmIxOUTQpabgmWrKEG0l9YuRMV1yzYbsm7aDcoKM=";
              };
            };
            src =
              srcs.${pkgs.stdenv.hostPlatform.system}
                or (throw "soci-snapshotter: unsupported platform ${pkgs.stdenv.hostPlatform.system}");
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "soci-snapshotter";
            inherit version;
            src = pkgs.fetchurl {
              inherit (src) url hash;
            };
            sourceRoot = ".";
            installPhase = ''
              install -Dm755 soci $out/bin/soci
              install -Dm755 soci-snapshotter-grpc $out/bin/soci-snapshotter-grpc
            '';
            meta = {
              description = "SOCI snapshotter for lazy-pulling OCI images via containerd";
              homepage = "https://github.com/awslabs/soci-snapshotter";
              license = lib.licenses.asl20;
              platforms = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              mainProgram = "soci-snapshotter-grpc";
            };
          };
        defaultText = lib.literalExpression "soci-snapshotter v0.14.1 static binaries";
        example = defaultText;
      };
    }
  );
}
