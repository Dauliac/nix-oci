{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    concatMapStrings
    concatStringsSep
    types
    ;
  cfg = config.oci.lib;
in
{
  options.lib = {
    mkRoot = mkOption {
      description = "A function to build container root filesystem with package, user setup, and dependencies";
      type = types.functionTo types.package;
      defaultText = lib.literalExpression ''
        { pkgs, tag, user, package ? null, dependencies ? [ ] }:
        pkgs.buildEnv {
          name = "root";
          version = tag;
          paths = (optional (package != null) package) ++ shadowSetup ++ dependencies;
          pathsToLink = [ "/bin" "/lib" "/etc" ];
        }
      '';
      default =
        {
          pkgs,
          tag,
          user,
          package ? null,
          dependencies ? [ ],
        }:
        let
          package' = if package == null then [ ] else [ package ];
          shadowSetup =
            if user == "root" then
              cfg.mkRootShadowSetup { inherit pkgs; }
            else if user != null && user != "" then
              cfg.mkNonRootShadowSetup { inherit pkgs user; }
            else
              throw "User must be specified";
        in
        (pkgs.buildEnv {
          name = "root";
          version = tag;
          paths = package' ++ shadowSetup ++ dependencies;
          pathsToLink = [
            "/bin"
            "/lib"
            "/etc"
          ];
        });
    };
    mkNixConfig = mkOption {
      description = "A function to build nix configuration file for containers";
      defaultText = lib.literalExpression ''pkgs: pkgs.writeText "etc/nix/nix.conf" "..."'';
      default =
        pkgs:
        pkgs.writeText "etc/nix/nix.conf" ''
          experimental-features = nix-command flakes
          build-users-group = nixbld
          sandbox = false
        '';
    };
    mkPublishOCIScript = mkOption {
      description = "A function to build publishing script for CI that pushes container images to registry";
      defaultText = lib.literalExpression ''{ container, pkgs }: pkgs.writeScriptBin "publish-docker-image" "..."'';
      default =
        {
          container,
          pkgs,
        }:
        pkgs.writeScriptBin "publish-docker-image" ''
          #!${pkgs.bash}/bin/bash

          set -o errexit
          set -o nounset
          set -o pipefail

          main() {
            local -r image_path="$CI_REGISTRY_IMAGE/${container.imageName}:${container.imageTag}"

            echo "Authenticating to the registry..."
            echo "$CI_REGISTRY_PASSWORD" | ${pkgs.skopeo}/bin/skopeo login --username "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"

            echo "Pushing image $image_path to the registry..."
            ${pkgs.skopeo}/bin/skopeo copy \
              docker-archive:${container.outPath} \
              docker://$image_path
            echo "Image pushed to $image_path"
          }

          main "$@"
        '';
    };
    mkRootShadowSetup = mkOption {
      description = "A function to build passwd, shadow, group, and gshadow files for containers run as root user";
      defaultText = lib.literalExpression ''{ pkgs }: [ (writeTextDir "etc/passwd" "...") (writeTextDir "etc/shadow" "...") ... ]'';
      default =
        { pkgs }:
        with pkgs;
        [
          (writeTextDir "etc/shadow" ''
            root:!x:::::::
          '')
          (writeTextDir "etc/passwd" ''
            root:x:0:0::/root:${runtimeShell}
          '')
          (writeTextDir "etc/group" ''
            root:x:0:
          '')
          (writeTextDir "etc/gshadow" ''
            root:x::
          '')
        ];
    };
    mkNonRootShadowSetup = mkOption {
      description = "A function to build passwd, shadow, group, and gshadow files for containers run as non-root user";
      defaultText = lib.literalExpression ''{ user, pkgs, uid ? 4000, gid ? uid }: [ (writeTextDir "etc/passwd" "...") ... ]'';
      default =
        {
          user,
          pkgs,
          uid ? 4000,
          gid ? uid,
        }:
        with pkgs;
        [
          (writeTextDir "etc/shadow" ''
            root:!x:::::::
            ${user}:!:::::::
          '')
          (writeTextDir "etc/passwd" ''
            root:x:0:0::/root:${runtimeShell}
            ${user}:x:${toString uid}:${toString gid}::/home/${user}:
          '')
          (writeTextDir "etc/group" ''
            root:x:0:
            ${user}:x:${toString gid}:
          '')
          (writeTextDir "etc/gshadow" ''
            root:x::
            ${user}:x::
          '')
        ];
    };
    mkNixShadowSetup = mkOption {
      description = "A function to build passwd, shadow, group, and gshadow files for containers that run nested Nix";
      defaultText = lib.literalExpression ''pkgs: [ (writeText "etc/passwd" "...") (writeText "etc/group" "...") ... ]'';
      default =
        pkgs:
        let
          numBuildUsers = 32;
        in
        with pkgs;
        [
          writeText
          "etc/passwd"
          ''
            root:x:0:0:System administrator:/root:${pkgs.bash}/bin/bash
            nobody:x:65534:65534:Unprivileged account (don't use!):/var/empty:${pkgs.shadow}/bin/nologin
            ${concatMapStrings (nixbldIndex: ''
              nixbld${toString nixbldIndex}:x:${toString (30000 + nixbldIndex)}:30000:Nix build user ${toString nixbldIndex}:/var/empty:/bin/false
            '') (builtins.genList (nixbldIndex: nixbldIndex + 1) numBuildUsers)}
          ''
          writeText
          "etc/group"
          ''
            root:x:0:root
            nobody:x:65534:nobody
            nixbld:x:30000:${
              concatStringsSep "," (
                map (nixbldIndex: "nixbld${toString nixbldIndex}") (
                  builtins.genList (nixbldIndex: nixbldIndex + 1) numBuildUsers
                )
              )
            }
          ''
          writeText
          "etc/shadow"
          ''
            root:!x:::::::
            nobody:!:::::::
            ${concatMapStrings (nixbldIndex: ''
              nixbld${toString nixbldIndex}:!:::::::
            '') (builtins.genList (nixbldIndex: nixbldIndex + 1) numBuildUsers)}
          ''
          writeText
          "etc/gshadow"
          ''
            root:x::
            nobody:x::
            nixbld:x::
          ''
        ];
    };
    mkPodmanPolicy = mkOption {
      description = "A function to build podman security policy configuration";
      defaultText = lib.literalExpression ''pkgs: pkgs.writeTextDir "etc/containers/policy.json" "..."'';
      default =
        pkgs:
        pkgs.writeTextDir "etc/containers/policy.json" ''
          {
              "default": [
                  {
                      "type": "insecureAcceptAnything"
                  }
              ]
          }
        '';
    };
  };
}
