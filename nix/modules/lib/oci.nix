{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
  cfg = config.oci.lib;
in
{
  options.oci.lib = {
    mkOCIPulledManifestLockUpdateScript = mkOption {
      description = "A function to build script to update pulled OCI manifests locks";
      type = types.functionTo types.package;
      default =
        {
          pkgs,
          self,
          perSystemConfig,
          config,
        }:
        let
          manifestRootPath = cfg.mkOCIPulledManifestLockRelativeRootPath {
            inherit (config) fromImageManifestRootPath;
            inherit self;
          };
          update = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              containerId: container:
              let
                inherit (perSystemConfig.containers.${containerId}) fromImage;
                manifestPath = cfg.mkOCIPulledManifestLockRelativePath {
                  inherit self;
                  inherit config perSystemConfig containerId;
                };
                manifest = cfg.mkOCIPulledManifestLock {
                  inherit config perSystemConfig containerId;
                };
              in
              ''
                declare -g manifest
                manifest=$(${manifest.getManifest}/bin/get-manifest)
                if [ -f "${manifestPath}" ]; then
                  currentContent=$(cat "${manifestPath}")
                  newContent=$(echo "$manifest")
                  if [ "$currentContent" != "$newContent" ]; then
                    printf "Updating lock manifest for ${containerId}::${fromImage.imageName}:${fromImage.imageTag} in ${manifestPath} ...\n"
                    echo "$manifest" > "${manifestPath}"
                  fi
                else
                  printf "Generating lock manifest for ${containerId}::${fromImage.imageName}:${fromImage.imageTag} in ${manifestPath} ...\n"
                  echo "$manifest" > "${manifestPath}"
                fi
              ''
            ) perSystemConfig.internal.pulledOCIs
          );
        in
        pkgs.writeShellScriptBin "update-pulled-oci-manifests-locks" ''
          set -o errexit
          set -o pipefail
          set -o nounset

          mkdir -p "${manifestRootPath}"
          ${update}
        '';
    };
    mkOCIPulledManifestLockPath = mkOption {
      description = "A function to build OCI manifest to pull";
      type = types.functionTo types.path;
      default =
        args@{
          config,
          perSystemConfig,
          containerId,
          ...
        }:
        let
          oci = args.perSystemConfig.containers.${args.containerId};
          name = "/" + lib.strings.replaceStrings [ "/" ] [ "-" ] oci.fromImage.imageName;
        in
        config.fromImageManifestRootPath + name + "-" + oci.fromImage.imageTag + "-manifest-lock.json";
    };
    mkOCIPulledManifestLockRelativeRootPath = mkOption {
      description = "A function to get relative path lock manifest of to pull OCI";
      type = types.functionTo types.str;
      default =
        args:
        "./"
        + (lib.strings.replaceStrings [ ((toString args.self) + "/") ] [ "" ] (
          toString args.fromImageManifestRootPath
        ))
        + "/";
    };
    mkOCIPulledManifestLockRelativePath = mkOption {
      description = "Generate local relive path to download OCI";
      type = types.functionTo types.str;
      default =
        args@{
          self,
          config,
          perSystemConfig,
          containerId,
        }:
        "./"
        + lib.strings.replaceStrings [ ((toString args.self) + "/") ] [ "" ] (
          toString (
            cfg.mkOCIPulledManifestLockPath {
              inherit (args) config perSystemConfig containerId;
            }
          )
        );
    };
    mkOCIPulledManifestLock = mkOption {
      description = "A function to build OCI manifest to pull";
      type = types.functionTo types.package;
      default =
        args@{
          perSystemConfig,
          containerId,
          config,
        }:
        let
          oci = perSystemConfig.containers.${containerId};
          fromImage' = oci.fromImage // {
            imageManifest = cfg.mkOCIPulledManifestLockPath args;
          };
          manifest = perSystemConfig.packages.nix2container.pullImageFromManifest fromImage';
        in
        manifest;
    };
    mkOCIName = mkOption {
      type = types.functionTo types.str;
      description = "A function to get name of container";
      default =
        {
          package,
          fromImage,
        }:
        if package != null then
          lib.strings.toLower package.meta.mainProgram
        else if fromImage != null then
          lib.strings.toLower fromImage.imageName
        else
          throw "Error: No valid source for name (name, package.meta.mainProgram, or fromImage.imageName) found.";
    };
    mkOCIUser = mkOption {
      type = types.functionTo types.str;
      description = "A function to get user of container";
      default =
        {
          isRoot,
          name,
        }:
        let
          user' =
            if isRoot then
              "root"
            else if name != null && name != "" then
              name
            else
              throw "No user given and impossible to infer it from name or isRoot";
        in
        user';
    };
    mkOCITag = mkOption {
      type = types.functionTo types.str;
      description = "A function to get tag of container";
      default =
        {
          package,
          fromImage,
        }:
        let
          tag' =
            if package != null && package.version != null then
              package.version
            else if fromImage != null && fromImage.imageTag != null then
              fromImage.imageTag
            else
              throw "Empty tag given and impossible to infer it from package or fromImage";
        in
        tag';
    };
    mkOCIEntrypoint = mkOption {
      type = types.functionTo (types.listOf types.str);
      description = "A function to get entrypoint of container";
      default =
        { package }:
        let
          entrypoint =
            if package != null then
              [
                "/bin/${package.meta.mainProgram}"
              ]
            else
              [ ];
        in
        entrypoint;
    };
    mkOCI = mkOption {
      description = "A function to build container";
      type = types.functionTo types.package;
      default =
        args@{
          pkgs,
          config,
          perSystemConfig,
          containerId,
        }:
        let
          oci = args.perSystemConfig.containers.${args.containerId};
          package = cfg.mkNixOrSimpleOCI args;
        in
        package
        // (
          if oci.cve.trivy.enabled then
            {
              cve.trivy = cfg.mkScriptCVETrivy {
                inherit
                  pkgs
                  containerId
                  perSystemConfig
                  config
                  ;
              };
            }
          else
            { }
        )
        // (
          if oci.cve.grype.enabled then
            {
              cve.grype = cfg.mkScriptCVEGrype {
                inherit pkgs containerId perSystemConfig;
              };
            }
          else
            { }
        )
        // (
          if oci.sbom.syft.enabled then
            {
              sbom.syft = cfg.mkScriptSBOMSyft {
                inherit pkgs containerId perSystemConfig;
              };
            }
          else
            { }
        )
        // (
          if oci.credentialsLeak.trivy.enabled then
            {
              credentialsLeak.trivy = cfg.mkScriptCredentialsLeakTrivy {
                inherit pkgs containerId perSystemConfig;
              };
            }
          else
            { }
        )
        // (
          if oci.test.containerStructureTest.enabled then
            {
              containerStructureTest = cfg.mkScriptContainerStructureTest {
                inherit pkgs containerId perSystemConfig;
              };
            }
          else
            { }
        )
        // (
          if oci.debug.enabled then
            {
              debug = cfg.mkDebugOCI args;
            }
          else
            { }
        );
    };
    mkDebugOCI = mkOption {
      description = "A function to build debug container.";
      type = types.functionTo types.package;
      default =
        args:
        let
          oci = args.perSystemConfig.containers.${args.containerId};
          debugConfig = {
            tag = oci.tag + "-debug";
            dependencies = oci.dependencies ++ oci.debug.packages;
            entrypoint =
              if oci.debug.entrypoint.enabled then
                [ "${oci.debug.entrypoint.wrapper}/bin/entrypoint" ] ++ oci.entrypoint
              else
                oci.entrypoint;
          };
          args' = args // {
            perSystemConfig = args.perSystemConfig // {
              containers.${args.containerId} = (builtins.removeAttrs oci [ "debug" ]) // debugConfig;
            };
          };
        in
        cfg.mkNixOrSimpleOCI args';
    };
    mkNixOrSimpleOCI = mkOption {
      description = "A function to that build nix or simple container depending config.";
      type = types.functionTo types.package;
      default =
        args:
        let
          oci = args.perSystemConfig.containers.${args.containerId};
        in
        if oci.installNix then cfg.mkNixOCI args else cfg.mkSimpleOCI args;
    };
    mkSimpleOCI = mkOption {
      description = "A function to build simple container";
      type = types.functionTo types.package;
      default =
        args:
        let
          oci = args.perSystemConfig.containers.${args.containerId};
        in
        (args.perSystemConfig.packages.nix2container.buildImage {
          inherit (oci) tag name;
          # NOTE: here we can't use mkIf because fromImage with empty value require an empty string

          fromImage =
            if oci.fromImage == null then
              ""
            else
              cfg.mkOCIPulledManifestLock {
                inherit (args) config perSystemConfig containerId;
              };
          copyToRoot = [
            (cfg.mkRoot {
              inherit (args) pkgs;
              inherit (oci)
                package
                dependencies
                tag
                user
                ;
            })
          ];
          config = {
            inherit (oci) entrypoint;
            User = oci.user;
            Env = [
              "PATH=/bin"
              "USER=${oci.user}"
            ];
          };
        });
    };
    mkNixOCI = mkOption {
      description = "A function to build nix container";
      type = types.functionTo types.package;
      default =
        args:
        let
          oci = args.perSystemConfig.containers.${args.containerId};
        in
        args.perSystemConfig.packages.nix2container.buildImage {
          inherit (oci) name tag;
          initializeNixDatabase = true;
          copyToRoot = [
            # TODO: add mkNixRoot function to build root with nix shadow setup
            # cfg.mkRoot
            # {
            #   inherit (oci) pkgs package tag "";
            #   user = "nixbld";
            # }
          ];
          layers = [
            (cfg.mkNixOCILayer {
              inherit (oci) user pkgs nix2container;
            })
          ];
          config = {
            inherit (oci) entrypoint;
          };
        };
    };
    mkNixOCILayer = mkOption {
      description = "A function to build nix container";
      type = types.package;
      default =
        args:
        let
          oci = args.config.oci.containers.${args.containerId};
        in
        args.perSystemConfig.packages.nix2container.buildLayer {
          copyToRoot = [
            (args.pkgs.buildEnv {
              name = "root";
              paths =
                with args.pkgs;
                [
                  coreutils
                  nix
                ]
                ++ (config.oci.lib.oci.mkNixShadowSetup pkgs);
              pathsToLink = [
                "/bin"
                "/etc"
              ];
            })
          ];
          config = {
            Env = [
              "NIX_PAGER=cat"
              "USER=${oci.user}"
              "HOME=/"
            ];
          };
        };
    };
    mkDockerArchive = mkOption {
      description = "A function to transform nix2container build into docker archive";
      type = types.functionTo types.package;
      default =
        {
          oci,
          skopeo,
          pkgs,
        }:
        pkgs.runCommandLocal "docker-archive"
          {
            buildInputs = [
              skopeo
            ];
            meta.description = "Run dive on built image.";
          }
          ''
            set -e
            skopeo --tmpdir $TMP --insecure-policy copy nix:${oci} docker-archive:archive.tar
            mv archive.tar $out
          '';
    };
    mkPodmanOCI = mkOption {
      description = "Function to build a container image with Podman and a non-root daemon.";
      # type = types.functionTo types.package;
      default =
        {
          nix2container,
          pkgs,
          package,
          dependencies ? [ ],
        }:
        let
          podmanConfig = pkgs.writeTextDir "etc/containers/containers.conf" ''
            [containers]
            log_level = "error"
            rootless = true
          '';
          entrypointScript = ./podman-oci-entrypoint.sh;
          tag = config.oci.lib.mkOCITag {
            inherit package;
            fromImage = null;
          };
          user = "podman";
        in
        nix2container.buildImage {
          name = "podman";
          inherit tag;
          copyToRoot = [
            (cfg.mkRoot {
              inherit pkgs package;
              inherit tag user;
              dependencies = [
                pkgs.podman
                podmanConfig
              ]
              ++ dependencies;
            })
            entrypointScript
          ];
          config = {
            # TODO: add user var and config here
            User = user;
            Env = [
              "USER=${user}"
            ];
            entrypoint = [
              "/podman-oci-entrypoint.sh"
              "$@"
            ];
          };
        };
    };
    mkPodmanOCIRunScript = mkOption {
      description = "Function to build a script into a podman container image";
      type = types.functionTo types.package;
      default =
        args@{
          nix2container,
          pkgs,
          package,
          dependencies ? [ ],
        }:
        let
          podman = config.oci.lib.mkPodmanOCI {
            inherit (args)
              nix2container
              pkgs
              package
              dependencies
              ;
          };
        in
        pkgs.writeShellScriptBin "run-in-podman" ''
          set -o errexit
          set -o pipefail
          set -o nounset

          set -x
          mkdir -p ./tmp
          export HOME=./tmp

          ${pkgs.strace}/bin/strace ${pkgs.podman}/bin/podman run --rm --detach ${podman.imageName}:${podman.imageTag}

          id=''$(${pkgs.podman}/bin/podman run --rm --detach ${podman.imageName}:${podman.imageTag})
          sleep 2
          ${pkgs.podman}/bin/podman exec $id "$@"
        '';
    };
  };
}
