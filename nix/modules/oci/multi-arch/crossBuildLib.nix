# Cross-build multi-arch OCI library functions
{
  lib,
  config,
  ...
}:
let
  inherit (lib) types;
  archDefs = import ../../_lib/arch.nix;
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
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
              crossPackage,
              crossDependencies ? [ ],
              arch,
            }:
            let
              ociLib = config.lib.oci or { };
              oci = perSystemConfig.containers.${containerId};
              fullName =
                if oci.registry != null && oci.registry != "" then "${oci.registry}/${oci.name}" else oci.name;
              home = if oci.user == "root" then "/root" else "/home/${oci.user}";

              # Reuse the NixOS eval from the native container (shadow,
              # certs, nsswitch are arch-independent)
              nixosEval = oci.nixosConfig.eval;

              root = ociLib.mkNixOSRoot {
                inherit nixosEval;
                package = crossPackage;
                inherit (oci) user;
                dependencies = crossDependencies;
              };

              nixosEnvVars = nixosEval.environment.variables or { };
              wantedEnvVars = [ "SSL_CERT_FILE" ];
              filteredEnvVars = lib.filterAttrs (k: _: builtins.elem k wantedEnvVars) nixosEnvVars;
              envList = [
                "PATH=/bin"
                "USER=${oci.user}"
                "HOME=${home}"
              ]
              ++ (lib.mapAttrsToList (k: v: "${k}=${v}") filteredEnvVars);
            in
            perSystemConfig.packages.nix2container.buildImage {
              inherit (oci) tag;
              inherit arch;
              name = fullName;
              copyToRoot = [ root ] ++ (oci.configFiles or [ ]);
              config = {
                inherit (oci) entrypoint;
                User = oci.user;
                Env = envList;
              }
              // lib.optionalAttrs (oci.labels != { }) {
                Labels = oci.labels;
              };
            };
        };

        mkMultiArchOCILayout = {
          type = types.functionTo types.package;
          description = "Merge per-arch nix2container images into a single OCI directory layout with nix2container-compatible passthru";
          fn =
            {
              perSystemConfig,
              containerId,
              images,
            }:
            let
              arches = lib.attrNames images;
              containerConfig = perSystemConfig.containers.${containerId};
              fullName =
                if containerConfig.registry != null && containerConfig.registry != "" then
                  "${containerConfig.registry}/${containerConfig.name}"
                else
                  containerConfig.name;
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
                      lib.mapAttrsToList (arch: image: ''
                        echo "==> Copying ${arch} image to OCI layout"
                        skopeo --insecure-policy copy nix:${image} oci:$out:${arch}
                      '') images
                    )}
                    regctl index create ocidir://$out:latest \
                      ${lib.concatStringsSep " " (
                        map (arch: "--ref ocidir://$out:${arch} --platform linux/${arch}") arches
                      )}
                    echo "==> Built multi-arch OCI layout: ${lib.concatStringsSep ", " arches}"
                  '';

              nativeArch = archDefs.systemToOCIArch pkgs.stdenv.hostPlatform.system;

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
              baseName =
                if containerConfig.registry != null && containerConfig.registry != "" then
                  "${containerConfig.registry}/${containerConfig.name}"
                else
                  containerConfig.name;
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
                echo "CIMERA_OCI_PUSHED_TAG ref=$PRIMARY_REF digest=$DIGEST tag=${primaryTag} primary=true"
                ${lib.concatMapStrings (tag: ''
                  echo "==> Tagging additional: ${tag}"
                  regctl image copy "$PRIMARY_REF" "$BASE_NAME:${tag}"
                  echo "CIMERA_OCI_PUSHED_TAG ref=$BASE_NAME:${tag} digest=$DIGEST tag=${tag} primary=false"
                '') additionalTags}
                echo "CIMERA_OCI_PUSHED ref=$PRIMARY_REF digest=$DIGEST tags=${lib.concatStringsSep "," (lib.attrNames containerConfig.tagConfigs)}"
              '';
            };
        };
      };
    };
}
