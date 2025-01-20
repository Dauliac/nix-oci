localflake:
{
  config,
  lib,
  inputs,
  self,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    attrsets
    foldl'
    ;
in
{
  options = {
    oci = {
      enabled = mkEnableOption "Enable the OCI module.";
      devShellPackage = mkOption {
        type = types.package;
        description = "The package to use for the dev shell.";
      };
      enableDevShell = mkOption {
        type = types.bool;
        description = "Enable the flake dev shell.";
        default = false;
      };
      enableCheck = mkOption {
        type = types.bool;
        description = "Enable the flake checks on built containers.";
        default = true;
      };
      fromImageManifestRootPath = mkOption {
        type = types.path;
        default = self + "/.oci/";
        description = "The root path to store the pulled OCI image manifest json lockfiles.";
      };
      registry = mkOption {
        type = types.str;
        default = "";
        description = "The OCI registry to use for pushing and pulling images.";
      };
    };
    perSystem = inputs.flake-parts.lib.mkPerSystemOption (
      {
        config,
        pkgs,
        system,
        ...
      }:
      {
        options.oci.skopeo = mkOption {
          type = types.package;
          description = "The package to use for skopeo.";
          default = localflake.inputs.nix2container.packages.${system}.skopeo-nix2container;
        };
        options.oci.nix2container = mkOption {
          type = types.attrs;
          description = "The nix2container package.";
          default = localflake.inputs.nix2container.packages.${system}.nix2container;
        };
        options.oci.containers = mkOption {
          type = types.attrsOf (
            types.submodule (
              { name, ... }:
              {
                options = {
                  tag = mkOption {
                    type = types.nullOr types.str;
                    description = "Tag of the container.";
                  };
                  package = mkOption {
                    type = types.nullOr types.package;
                    description = "The main package for the container";
                    default = null;
                  };
                  name = mkOption {
                    type = types.nullOr types.str;
                    description = "Name of the container.";
                    default = null;
                  };
                  fromImage = mkOption {
                    description = "The image to use as the base image.";
                    type = types.attrsOf types.str;
                    default = { };
                    example = {
                      imageName = "library/alpine";
                      imageTag = "1.2.3";
                      os = "linux";
                      arch = "amd64";
                    };
                  };
                  dependencies = mkOption {
                    type = types.listOf types.package;
                    description = "Additional dependencies packages to include in the container.";
                    default = [ ];
                  };
                  isRoot = mkOption {
                    type = types.bool;
                    description = "Whether the container is a root container.";
                    default = false;
                  };
                  installNix = mkOption {
                    type = types.bool;
                    description = "Whether to install nix in the container.";
                    default = false;
                  };
                  push = mkOption {
                    type = types.bool;
                    description = "Whether to push the container to the OCI registry.";
                    default = false;
                  };
                };
              }
            )
          );
          description = "Definitions for all containers.";
          default = { };
          example = {
            package = pkgs.hello;
            dependencies = [ pkgs.bash ];
          };
        };
      }
    );
  };
  config = mkIf (config.oci != null && config.oci.enabled) {
    perSystem =
      {
        config,
        pkgs,
        inputs',
        system,
        ...
      }:
      let
        inherit (config.oci) nix2container;
        pulledOCI =
          attrsets.mapAttrs
            (
              containerName: containerConfig:
              if containerConfig.fromImage != { } then
                nix2container.pullImageFromManifest containerConfig.fromImage
                // {
                  imageManifest = cfg.lib.mkOCIPulledManifestLockPath {
                    inherit (cfg.oci) fromImageManifestRootPath;
                    inherit (containerConfig) fromImage;
                  };
                }
              else
                null
            )
            (attrsets.filterAttrs (_: containerConfig: containerConfig.fromImage != { }) config.oci.containers);
        oci = attrsets.mapAttrs (
          containerName: containerConfig:
          localflake.config.lib.mkOCI {
            inherit (cfg.oci) fromImageManifestRootPath;
            inherit pkgs;
            inherit (containerConfig)
              package
              tag
              name
              dependencies
              isRoot
              installNix
              fromImage
              ;
            inherit nix2container;
          }
        ) config.oci.containers;
        prefixedOCI = foldl' (
          acc: containerName:
          acc
          // {
            "oci-${containerName}" = oci.${containerName};
          }
        ) { } (attrsets.attrNames oci);
        allOCI = pkgs.runCommand "oci-all" {
            buildInputs = [];
            inherit (lib) attrsets;
            inherit (config.oci) containers;
          } ''
            mkdir -p $out
            ${lib.concatMapStringsSep "\n" (name: ''
              echo "Building container: ${name}"
              cp ${prefixedOCI.${name}} $out/${name}
            '') (attrsets.attrNames prefixedOCI)}
          '';
        updatePulledOCIManifestLocks = localflake.config.lib.mkOCIPulledManifestLockUpdateScript {
          inherit
            pkgs
            self
            nix2container
            pulledOCI
            ;
          inherit (config.oci) containers;
          inherit (cfg.oci) fromImageManifestRootPath;
        };
        diveChecks = lib.genAttrs (lib.attrNames oci) (
          containerName:
          localflake.config.lib.mkCheckDive {
            oci = prefixedOCI.${containerName};
            inherit pkgs;
            dive = pkgs.dive;
            inherit (config.oci) skopeo;
          }
        );
        prefixedDiveChecks = foldl' (
          acc: containerName:
          acc
          // {
            "oci-dive-check-${containerName}" = diveChecks.${containerName};
          }
        ) { } (attrsets.attrNames diveChecks);
      in
      {
        apps = {
          oci-updatePulledManifestsLocks = {
            type = "app";
            program = updatePulledOCIManifestLocks;
          };
        };
        packages = lib.mkMerge [
          {
            oci-updatePulledManifestsLocks = updatePulledOCIManifestLocks;
            oci-all = allOCI;
          }
          prefixedOCI
        ];

        checks = mkIf cfg.oci.enableCheck prefixedDiveChecks;

        devShells.default = mkIf cfg.oci.enableDevShell (
          pkgs.mkShell {
            shellHook = ''
              ${config.packages.oci-updatePulledManifestsLocks}/bin/update-pulled-oci-manifests-locks
            '';
          }
        );
      };
  };
}
