# Cross-build multi-arch OCI library functions
{ lib, ... }:
let
  inherit (lib) types;
  # archData replaced by config.lib.oci inside perSystem
in
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      # Use the shared deploy lib via nix-lib (typed, documented, tested)
      ociDeployLib = config.lib.oci or { };
    in
    {
      nix-lib.lib.oci = {
        mkCrossOCI = {
          type = types.functionTo types.package;
          description = "Build a container image for a non-native architecture using cross-compiled packages";
          file = "nix/modules/oci/multi-arch/crossBuildLib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              crossPackage,
              crossDependencies ? [ ],
              arch,
            }:
            let
              ociLib = config.lib.oci or { };
              oci = perSystemConfig.containers.${containerId};
              fullName = ociLib.mkRepoRef { inherit (oci) registry name; };

              # Reuse the NixOS eval from the native container (shadow,
              # certs, nsswitch are arch-independent)
              nixosEval = oci.nixosConfig.eval;
              out = nixosEval.oci.container._output;

              # Cross root: shadow/etc from eval + cross-compiled package/deps
              root = pkgs.buildEnv {
                name = "root";
                paths =
                  (lib.optional (crossPackage != null) crossPackage)
                  ++ crossDependencies
                  ++ out.shadowFiles
                  ++ out.etcFiles
                  ++ [
                    nixosEval.oci.lib.mkHomeDirDrv
                    (pkgs.runCommand "fhs-tmp" { } "mkdir -p $out/tmp $out/var/tmp")
                  ];
                pathsToLink = [
                  "/bin"
                  "/lib"
                  "/etc"
                  "/home"
                  "/root"
                  "/tmp"
                  "/var"
                ];
              };
            in
            perSystemConfig.packages.nix2container.buildImage {
              inherit (oci) tag;
              inherit arch;
              name = fullName;
              copyToRoot = [ root ];
              config = {
                entrypoint = if out.entrypoint != [ ] then out.entrypoint else oci.entrypoint;
                User = oci.user;
                Env = out.envVars;
              }
              // lib.optionalAttrs (oci.labels != { }) {
                Labels = oci.labels;
              };
            };
        };

        mkMultiArchOCILayout = {
          type = types.functionTo types.package;
          description = "Merge per-arch nix2container images into a single OCI directory layout with nix2container-compatible passthru";
          file = "nix/modules/oci/multi-arch/crossBuildLib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              images,
            }:
            let
              # `images` is keyed by Nix target system (e.g.
              # "armv7l-linux"), never by OCI arch. Both the layout tag
              # and the manifest platform are derived from the system
              # here so the OCI variant ("linux/arm/v7") survives;
              # systemToOCIArch alone discards it.
              targetSystems = lib.attrNames images;
              arches = map ociDeployLib.systemToOCIArch targetSystems;
              containerConfig = perSystemConfig.containers.${containerId};
              fullName = ociDeployLib.mkRepoRef { inherit (containerConfig) registry name; };
              primaryTag = builtins.head (
                lib.attrNames (lib.filterAttrs (_: tc: tc.primary) containerConfig.tagConfigs)
              );
              skopeo = perSystemConfig.packages.skopeo;

              layout =
                pkgs.runCommand "multiarch-${containerId}"
                  {
                    nativeBuildInputs = [
                      skopeo
                      perSystemConfig.packages.regctl
                    ];
                  }
                  ''
                    mkdir -p $out
                    ${lib.concatStringsSep "\n" (
                      lib.mapAttrsToList (sys: image: ''
                        echo "==> Copying ${ociDeployLib.systemToOCIArch sys} image to OCI layout"
                        skopeo --insecure-policy copy nix:${image} oci:$out:${ociDeployLib.systemToOCIArch sys}
                      '') images
                    )}
                    regctl index create ocidir://$out:latest \
                      ${lib.concatStringsSep " " (
                        map (
                          sys:
                          "--ref ocidir://$out:${ociDeployLib.systemToOCIArch sys} --platform ${ociDeployLib.systemToOCIPlatform sys}"
                        ) targetSystems
                      )}
                    echo "==> Built multi-arch OCI layout: ${lib.concatStringsSep ", " arches}"
                  '';

              nativeArch = ociDeployLib.systemToOCIArch pkgs.stdenv.hostPlatform.system;

              # nix2container-compatible passthru scripts
              copyToDockerDaemon = pkgs.writeShellApplication {
                name = "copy-to-docker-daemon";
                runtimeInputs = [ skopeo ];
                text = ''
                  echo "==> Loading ${nativeArch} image into Docker daemon"
                  skopeo --insecure-policy copy \
                    oci:${layout}:${nativeArch} \
                    "${ociDeployLib.skopeoDestPrefix "docker"}${fullName}:${primaryTag}"
                  echo "==> Loaded ${fullName}:${primaryTag} (${nativeArch})"
                '';
              };

              copyToPodman = pkgs.writeShellApplication {
                name = "copy-to-podman";
                runtimeInputs = [ skopeo ];
                text = ''
                  echo "==> Loading ${nativeArch} image into Podman"
                  skopeo --insecure-policy copy \
                    oci:${layout}:${nativeArch} \
                    "${ociDeployLib.skopeoDestPrefix "podman"}${fullName}:${primaryTag}"
                  echo "==> Loaded ${fullName}:${primaryTag} (${nativeArch})"
                '';
              };

              copyToRegistry = pkgs.writeShellApplication {
                name = "copy-to-registry";
                runtimeInputs = [ skopeo ];
                text = ''
                  REF="''${1:-${fullName}:${primaryTag}}"
                  echo "==> Pushing multi-arch image to registry"
                  echo "    source: oci:${layout}:latest"
                  echo "    target: docker://$REF"
                  skopeo copy --all --insecure-policy \
                    oci:${layout}:latest \
                    "docker://$REF"
                  echo "==> Pushed $REF (architectures: ${lib.concatStringsSep ", " arches})"
                '';
              };
            in
            layout.overrideAttrs (_: {
              passthru = {
                imageName = fullName;
                imageTag = primaryTag;
                inherit copyToDockerDaemon copyToPodman copyToRegistry;
              };
            });
        };

        mkPushOCILayoutApp = {
          type = types.functionTo types.package;
          description = "Push a multi-arch OCI directory layout to a registry";
          file = "nix/modules/oci/multi-arch/crossBuildLib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              layout,
            }:
            let
              containerConfig = perSystemConfig.containers.${containerId};
              primaryTag = builtins.head (
                lib.attrNames (lib.filterAttrs (_: tc: tc.primary) containerConfig.tagConfigs)
              );
              additionalTags = lib.attrNames (lib.filterAttrs (_: tc: !tc.primary) containerConfig.tagConfigs);
              baseName = ociDeployLib.mkRepoRef { inherit (containerConfig) registry name; };
            in
            pkgs.writeShellApplication {
              name = "push-multiarch-${containerId}";
              runtimeInputs = [
                perSystemConfig.packages.skopeo
                perSystemConfig.packages.regctl
              ];
              text = ''
                BASE_NAME="''${CI_REGISTRY_IMAGE:-}${baseName}"
                PRIMARY_REF="$BASE_NAME:${primaryTag}"
                echo "==> Pushing multi-arch OCI image"
                echo "    source: oci:${layout}:latest"
                echo "    target: $PRIMARY_REF"
                skopeo copy --all --insecure-policy \
                  oci:${layout}:latest \
                  "docker://$PRIMARY_REF"
                DIGEST="$(skopeo inspect --raw "docker://$PRIMARY_REF" 2>/dev/null | sha256sum | cut -d' ' -f1)"
                DIGEST="sha256:$DIGEST"
                echo "==> Pushed: $PRIMARY_REF (digest: $DIGEST)"
                echo "NIX_OCI_PUSHED_TAG ref=$PRIMARY_REF digest=$DIGEST tag=${primaryTag} primary=true"
                # Authoritative digest marker for oci-attach-referrer-substrate.
                echo "NIX_OCI_PUSHED_DIGEST=$DIGEST"
                ${lib.concatMapStrings (tag: ''
                  echo "==> Tagging additional: ${tag}"
                  regctl image copy "$PRIMARY_REF" "$BASE_NAME:${tag}"
                  echo "NIX_OCI_PUSHED_TAG ref=$BASE_NAME:${tag} digest=$DIGEST tag=${tag} primary=false"
                '') additionalTags}
                echo "NIX_OCI_PUSHED ref=$PRIMARY_REF digest=$DIGEST tags=${lib.concatStringsSep "," (lib.attrNames containerConfig.tagConfigs)}"
              '';
            };
        };
      };
    };
}
