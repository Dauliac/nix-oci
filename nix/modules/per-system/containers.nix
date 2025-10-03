{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkEnableOption
    mkOption
    types
    ;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        config,
        system,
        ...
      }:
      let
        perSystemConfig = config;
      in
      {
        options.oci.containers = mkOption {
          type = types.attrsOf (
            types.submodule (
              {
                name,
                config,
                ...
              }:
              let
                containerConfig = config;
              in
              {
                options = {
                  rootPath = mkOption {
                    type = types.path;
                    description = "The root path for the container.";
                    default = cfg.oci.rootPath + name + "/";
                    defaultText = lib.literalExpression ''config.oci.rootPath + name + "/"'';
                  };
                  tag = mkOption {
                    type = types.nullOr types.str;
                    description = "Tag of the container.";
                    default = cfg.oci.lib.mkOCITag {
                      inherit (containerConfig) package fromImage;
                    };
                    defaultText = lib.literalExpression ''config.oci.lib.mkOCITag { inherit package fromImage; }'';
                    example = "1.0.0";
                  };
                  # TODO: should we had an OTLP wrapper ?
                  test = mkOption {
                    description = ".";
                    default = { };
                    type = types.submodule {
                      options = {
                        rootPath = mkOption {
                          type = types.path;
                          description = "The root path for the test.";
                          default = cfg.oci.rootPath + name + "/test/";
                          defaultText = lib.literalExpression ''config.oci.rootPath + name + "/test/"'';
                        };
                        dive = mkOption {
                          description = "Configuration for Dive analysis of container image layers and efficiency.";
                          default = { };
                          type = types.submodule {
                            options = {
                              enabled = mkOption {
                                type = types.bool;
                                description = "Whether to enable Dive analysis for container image layers and efficiency.";
                                default = cfg.oci.test.dive.enabled;
                                defaultText = lib.literalExpression "cfg.oci.test.dive.enabled";
                                example = true;
                              };
                            };
                          };
                        };
                        containerStructureTest = mkOption {
                          description = "Configuration for container-structure-test to validate container structure and metadata.";
                          default = { };
                          type = types.submodule {
                            options = {
                              enabled = mkOption {
                                type = types.bool;
                                description = "Whether to enable container-structure-test for validating container structure and metadata.";
                                default = cfg.oci.test.containerStructureTest.enabled;
                                defaultText = lib.literalExpression "cfg.oci.test.containerStructureTest.enabled";
                              };
                              configs = mkOption {
                                type = types.listOf types.path;
                                description = "List of container-structure-test configuration files to run.";
                                default = [
                                  (cfg.oci.rootPath + name + "/test/container-structure-test.yaml")
                                ];
                                defaultText = lib.literalExpression ''[ (cfg.oci.rootPath + name + "/test/container-structure-test.yaml") ]'';
                              };
                            };
                          };
                        };
                        dgoss = mkOption {
                          description = "Configuration for dgoss (Docker + goss) testing framework.";
                          default = { };
                          type = types.submodule {
                            options = {
                              enabled = mkOption {
                                type = types.bool;
                                description = "Whether to enable dgoss testing for the container.";
                                default = cfg.oci.test.dgoss.enabled;
                                defaultText = lib.literalExpression "cfg.oci.test.dgoss.enabled";
                              };
                              optionsPath = mkOption {
                                type = types.path;
                                description = "Path to the dgoss configuration file.";
                                default = cfg.oci.rootPath + name + "/test/dgoss.yaml";
                                defaultText = lib.literalExpression ''config.oci.rootPath + name + "/test/dgoss.yaml"'';
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                  debug = mkOption {
                    description = "Configuration for debug builds with additional debugging tools and packages.";
                    default = { };
                    type = types.submodule {
                      options = {
                        enabled = mkOption {
                          type = types.bool;
                          description = "Whether to enable debug build with additional debugging tools.";
                          default = perSystemConfig.oci.debug.enabled;
                          defaultText = lib.literalExpression "perSystemConfig.oci.debug.enabled";
                        };
                        packages = mkOption {
                          type = types.listOf types.package;
                          description = "List of additional packages to include in debug builds.";
                          default = perSystemConfig.oci.debug.packages;
                          defaultText = lib.literalExpression "perSystemConfig.oci.debug.packages";
                        };
                        entrypoint = mkOption {
                          description = "Debug entrypoint wrapper configuration.";
                          type = types.submodule {
                            options = {
                              enabled = mkOption {
                                type = types.bool;
                                description = "Whether to enable debug entrypoint wrapper.";
                                default = perSystemConfig.oci.debug.entrypoint.enabled;
                                defaultText = lib.literalExpression "perSystemConfig.oci.debug.entrypoint.enabled";
                              };
                              wrapper = mkOption {
                                type = types.package;
                                description = "Package containing the debug entrypoint wrapper.";
                                default = perSystemConfig.oci.debug.entrypoint.wrapper;
                                defaultText = lib.literalExpression "perSystemConfig.oci.debug.entrypoint.wrapper";
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                  credentialsLeak = mkOption {
                    description = ".";
                    default = { };
                    type = types.submodule {
                      options = {
                        trivy = mkOption {
                          description = "The package to use for the cve check.";
                          default = { };
                          type = types.submodule {
                            options = {
                              enabled = mkOption {
                                type = types.bool;
                                description = "";
                                default = cfg.oci.cve.trivy.enabled;
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                  sbom = mkOption {
                    description = ".";
                    default = { };
                    type = types.submodule {
                      options = {
                        rootPath = mkOption {
                          type = types.path;
                          description = "The root path for the sbom.";
                          default = cfg.oci.rootPath + name + "/sbom/";
                          defaultText = lib.literalExpression ''config.oci.rootPath + name + "/sbom/"'';
                        };
                        syft = mkOption {
                          description = "";
                          default = { };
                          type = types.submodule {
                            options = {
                              enabled = mkOption {
                                type = types.bool;
                                description = "";
                                default = cfg.oci.sbom.syft.enabled;
                              };
                              config = mkOption {
                                description = "";
                                default = { };
                                type = types.submodule {
                                  options = {
                                    enabled = mkOption {
                                      type = types.bool;
                                      description = "";
                                      default = cfg.oci.sbom.syft.config.enabled;
                                    };
                                    path = mkOption {
                                      type = types.path;
                                      description = "";
                                      default = cfg.oci.rootPath + name + "/sbom/syft.yaml";
                                      defaultText = lib.literalExpression ''config.oci.rootPath + name + "/sbom/syft.yaml"'';
                                    };
                                  };
                                };
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                  cve = mkOption {
                    description = "Whether to check for CVEs.";
                    default = { };
                    type = types.submodule {
                      options = {
                        rootPath = mkOption {
                          type = types.path;
                          description = "";
                          default = cfg.oci.rootPath + name + "/cve/";
                          defaultText = lib.literalExpression ''config.oci.rootPath + name + "/cve/"'';
                        };
                        trivy = mkOption {
                          description = "The package to use for the cve check.";
                          default = { };
                          type = types.submodule {
                            options = {
                              enabled = mkOption {
                                type = types.bool;
                                description = "";
                                default = cfg.oci.cve.trivy.enabled;
                              };
                              ignore = mkOption {
                                description = "";
                                default = { };
                                type = types.submodule {
                                  options = {
                                    fileEnabled = mkEnableOption "";
                                    path = mkOption {
                                      type = types.nullOr types.path;
                                      description = "";
                                      default = cfg.oci.rootPath + name + "/cve/trivy.ignore";
                                      defaultText = lib.literalExpression ''config.oci.rootPath + name + "/cve/trivy.ignore"'';
                                    };
                                    extra = mkOption {
                                      type = types.listOf types.str;
                                      description = "Extra CVE to ignore.";
                                      default = [ ];
                                    };
                                  };
                                };
                              };
                            };
                          };
                        };
                        grype = mkOption {
                          description = "";
                          default = { };
                          type = types.submodule {
                            options = {
                              enabled = mkOption {
                                type = types.bool;
                                description = "Whether to run grype.";
                                default = cfg.oci.cve.grype.enabled;
                              };
                              config = mkOption {
                                description = "The path to the grype config.";
                                default = { };
                                type = types.submodule {
                                  options = {
                                    enabled = mkOption {
                                      type = types.bool;
                                      description = "";
                                      default = cfg.oci.cve.grype.config.enabled;
                                    };
                                    path = mkOption {
                                      type = types.path;
                                      description = "";
                                      default = cfg.oci.rootPath + name + "/cve/grype.yaml";
                                      defaultText = lib.literalExpression ''config.oci.rootPath + name + "/cve/grype.yaml"'';
                                    };
                                  };
                                };
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                  package = mkOption {
                    type = types.nullOr types.package;
                    description = "The main package for the container";
                    default = null;
                    example = lib.literalExpression "pkgs.hello";
                  };
                  name = mkOption {
                    type = types.nullOr types.str;
                    description = "Name of the container. If null, the name will be automatically generated from the package or base image.";
                    default = cfg.oci.lib.mkOCIName {
                      inherit (containerConfig) package fromImage;
                    };
                    defaultText = lib.literalExpression "cfg.oci.lib.mkOCIName { inherit package fromImage; }";
                    example = "my-app";
                  };
                  user = mkOption {
                    type = types.nullOr types.str;
                    description = "The user to run the container as. If null, will be automatically determined based on isRoot setting.";
                    default = cfg.oci.lib.mkOCIUser {
                      inherit (containerConfig) name isRoot;
                    };
                    defaultText = lib.literalExpression "cfg.oci.lib.mkOCIUser { inherit name isRoot; }";
                  };
                  fromImage = mkOption {
                    description = "The base image to use as the foundation for this container. If null, will create a minimal scratch-based container.";
                    type = types.nullOr (
                      types.submodule (
                        { ... }:
                        {
                          options = {
                            imageName = mkOption {
                              type = types.nullOr types.str;
                              description = "The name of the base image.";
                              example = "library/alpine";
                              default = null;
                            };
                            imageTag = mkOption {
                              type = types.str;
                              description = "The tag/version of the image.";
                              example = "3.21.2";
                            };
                            os = mkOption {
                              type = types.enum [
                                "linux"
                              ];
                              description = "The operating system for the image.";
                              example = "linux";
                              default = "linux";
                            };
                            arch = mkOption {
                              type = types.enum [
                                "amd64"
                                "arm64"
                              ];
                              description = "The architecture of the image.";
                              example = "amd64";
                              default =
                                if system == "x86_64-linux" then
                                  "amd64"
                                else if system == "aarch64-linux" then
                                  "arm64"
                                else
                                  throw "Unsupported system: ${system} as default arch, please set the arch option.";
                              defaultText = lib.literalExpression ''
                                if system == "x86_64-linux" then
                                  "amd64"
                                else if system == "aarch64-linux" then
                                  "arm64"
                                else
                                  throw "Unsupported system: ''${system} as default arch, please set the arch option."
                              '';
                            };
                          };
                        }
                      )
                    );
                    default = null;
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
                    example = lib.literalExpression "[ pkgs.bash pkgs.coreutils ]";
                  };
                  isRoot = mkOption {
                    type = types.bool;
                    description = "Whether the container is a root container.";
                    default = false;
                    example = true;
                  };
                  installNix = mkOption {
                    type = types.bool;
                    description = "Whether to install nix in the container.";
                    default = false;
                    example = true;
                  };
                  push = mkOption {
                    type = types.bool;
                    description = "Whether to push the container to the OCI registry.";
                    default = false;
                    example = true;
                  };
                  entrypoint = mkOption {
                    type = types.listOf types.str;
                    description = "The entrypoint command and arguments for the container. Will be automatically generated from the package if not specified.";
                    default = cfg.oci.lib.mkOCIEntrypoint { inherit (containerConfig) package; };
                    defaultText = lib.literalExpression "cfg.oci.lib.mkOCIEntrypoint { inherit package; }";
                    example = [ "/bin/sh" "-c" "echo hello" ];
                  };
                };
              }
            )
          );
          description = "Definitions for all containers managed by this flake.";
          default = { };
          example = lib.literalExpression ''
            {
                        my-app = {
                          package = pkgs.hello;
                          dependencies = [ pkgs.bash ];
                          fromImage = {
                            imageName = "library/alpine";
                            imageTag = "3.21.2";
                          };
                          isRoot = false;
                        };
                      }'';
        };
      }
    );
  };
}
