{
  config,
  lib,
  self,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    types
    attrsets
    ;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        config,
        pkgs,
        system,
        ...
      }:
      let
        ociLib = config.lib.oci or { };
      in
      {
        options.oci.internal = {
          pulledOCIs = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default =
              attrsets.mapAttrs
                (
                  containerId: containerConfig:
                  ociLib.mkOCIPulledManifestLock {
                    perSystemConfig = config.oci;
                    globalConfig = cfg.oci;
                    inherit containerId;
                  }
                )
                (
                  attrsets.filterAttrs (_: containerConfig: containerConfig.fromImage.enabled) config.oci.containers
                );
          };
          OCIs = mkOption {
            description = "Built OCI container images.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: containerConfig:
              ociLib.mkOCI {
                perSystemConfig = config.oci;
                globalConfig = cfg.oci;
                inherit containerId;
              }
            ) config.oci.containers;
          };
          # Flavour images: synthetic containers from flavour expansion.
          # Each flavour is a full container evaluated through the same
          # pipeline — we just need to make it findable by mkOCI.
          flavourOCIs = mkOption {
            description = "Built OCI images from flavour expansion.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default =
              let
                flavourContainers = config.oci.internal._flavourContainers;
                # mkOCI reads perSystemConfig.containers.${containerId}, so we
                # construct a perSystemConfig that includes the synthetic containers.
                allPerSystem = config.oci // {
                  containers = config.oci.containers // flavourContainers;
                };
              in
              attrsets.mapAttrs (
                syntheticId: _:
                ociLib.mkOCI {
                  perSystemConfig = allPerSystem;
                  globalConfig = cfg.oci;
                  containerId = syntheticId;
                }
              ) flavourContainers;
          };
          _flavourPerSystem = mkOption {
            type = types.unspecified;
            internal = true;
            readOnly = true;
            description = "Merged perSystemConfig for flavour-aware lookups (containers + OCIs).";
            default =
              let
                flavourContainers = config.oci.internal._flavourContainers;
              in
              config.oci
              // {
                containers = config.oci.containers // flavourContainers;
                internal = config.oci.internal // {
                  OCIs = config.oci.internal.OCIs // config.oci.internal.flavourOCIs;
                };
              };
          };
          prefixedOCIs = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-";
              set = config.oci.internal.OCIs // config.oci.internal.flavourOCIs;
            };
          };
          sandboxApps = mkOption {
            description = "Per-container bubblewrap sandbox scripts.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: containerConfig:
              let
                nixosEval = containerConfig.nixosConfig.eval;
                out = nixosEval.oci.container._output;
              in
              ociLib.mkSandboxScript {
                name = containerId;
                rootFilesystem = out.rootFilesystem;
                entrypoint = if out.entrypoint != [ ] then out.entrypoint else containerConfig.entrypoint;
                environment = containerConfig.environment;
                # Use the NixOS eval's user (matches the filesystem) rather than
                # the flake-parts user (may differ when auto-derived from package name).
                user = nixosEval.oci.container.user;
                isRoot = containerConfig.isRoot;
                workingDir = out.workingDir or containerConfig.workingDir or null;
                inherit pkgs;
              }
            ) config.oci.containers;
          };
          prefixedSandboxApps = mkOption {
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs' (
              name: app:
              attrsets.nameValuePair "oci-sandbox-${name}" {
                type = "app";
                program = lib.getExe app;
              }
            ) config.oci.internal.sandboxApps;
          };
          updatepulledOCIsManifestLocks = mkOption {
            type = types.package;
            internal = true;
            readOnly = true;
            default = ociLib.mkOCIPulledManifestLockUpdateScript {
              inherit self;
              perSystemConfig = config.oci;
              globalConfig = cfg.oci;
            };
          };
          # ========== PER-TAG PUSH APPS ==========
          #
          # One derivation per tag declared on each container. This
          # reifies each push as a standalone unit so consumers (e.g.
          # cimera's DirectExecutor) can schedule them in parallel,
          # retry per-tag, and emit per-tag events / markers.
          #
          # Shape: attrsOf (attrsOf package). Outer key is
          # containerId; inner key is the tag literal.
          pushApps = mkOption {
            description = ''
              Per-tag push apps for each container. Keys are
              containerIds; each entry is itself an attrset keyed by
              tag literal. Every tag in `containerConfig.tagConfigs`
              produces one app; the first tag is flagged as
              `primary = true` in its marker output.
            '';
            type = types.attrsOf (types.attrsOf types.package);
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: containerConfig:
              attrsets.mapAttrs (
                _tag: tagConfig:
                ociLib.mkPushApp {
                  perSystemConfig = config.oci;
                  inherit containerId tagConfig;
                }
              ) containerConfig.tagConfigs
            ) config.oci.containers;
          };
          prefixedPushApps = mkOption {
            description = "Flat app attrset (for flake.apps.*) with `oci-push-<container>-<tag>` keys.";
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = lib.pipe config.oci.internal.pushApps [
              (attrsets.mapAttrsToList (
                containerId: tagsMap:
                attrsets.mapAttrs' (
                  tag: app:
                  attrsets.nameValuePair "oci-push-${containerId}-${tag}" {
                    type = "app";
                    program = lib.getExe app;
                  }
                ) tagsMap
              ))
              (builtins.foldl' (a: b: a // b) { })
            ];
          };
          flavourPushApps = mkOption {
            description = ''
              Per-tag push apps for flavour images. Same structure as pushApps.
            '';
            type = types.attrsOf (types.attrsOf types.package);
            internal = true;
            readOnly = true;
            default =
              let
                flavourContainers = config.oci.internal._flavourContainers;
                allPerSystem = config.oci.internal._flavourPerSystem;
              in
              attrsets.mapAttrs (
                syntheticId: syntheticConfig:
                attrsets.mapAttrs (
                  _tag: tagConfig:
                  ociLib.mkPushApp {
                    perSystemConfig = allPerSystem;
                    containerId = syntheticId;
                    inherit tagConfig;
                  }
                ) syntheticConfig.tagConfigs
              ) flavourContainers;
          };
          prefixedFlavourPushApps = mkOption {
            description = "Flat app attrset for flavour pushes.";
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = lib.pipe config.oci.internal.flavourPushApps [
              (attrsets.mapAttrsToList (
                syntheticId: tagsMap:
                attrsets.mapAttrs' (
                  tag: app:
                  attrsets.nameValuePair "oci-push-${syntheticId}-${tag}" {
                    type = "app";
                    program = lib.getExe app;
                  }
                ) tagsMap
              ))
              (builtins.foldl' (a: b: a // b) { })
            ];
          };
          # ========== ALL-TAGS PUSH APPS (efficient) ==========
          #
          # One derivation per container that pushes all tags. The primary
          # tag is pushed from the Nix store; additional tags are created
          # via registry-side copies (zero blob re-upload).
          pushAllTagsApps = mkOption {
            description = ''
              Efficient all-tags push apps, keyed by containerId.
              Pushes the primary tag once from the Nix store, then
              creates additional tags via registry-side copies.
            '';
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: _containerConfig:
              ociLib.mkPushAllTagsApp {
                perSystemConfig = config.oci;
                inherit containerId;
              }
            ) config.oci.containers;
          };
          flavourPushAllTagsApps = mkOption {
            description = ''
              Same as `pushAllTagsApps` but for flavour images.
            '';
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              syntheticId: _:
              ociLib.mkPushAllTagsApp {
                perSystemConfig = config.oci.internal._flavourPerSystem;
                containerId = syntheticId;
              }
            ) config.oci.internal._flavourContainers;
          };
          pushTmpOCIApps = mkOption {
            description = "Apps to push architecture-specific temporary images for multi-arch builds. Keyed by containerId-arch.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default =
              let
                arch = if ociLib.archMap ? ${system} then ociLib.systemToOCIArch system else null;
              in
              if arch == null then
                { }
              else
                lib.pipe config.oci.containers [
                  (attrsets.filterAttrs (_: c: c.multiArch.enabled))
                  (attrsets.mapAttrs' (
                    containerId: containerConfig:
                    # Include arch in the key for explicit naming
                    attrsets.nameValuePair "${containerId}-${arch}" (
                      ociLib.mkPushTempOCIApp {
                        perSystemConfig = config.oci;
                        inherit containerId arch;
                      }
                    )
                  ))
                ];
          };
          prefixedPushTmpOCIApps = mkOption {
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs' (
              name: app:
              # name is already containerId-arch
              attrsets.nameValuePair "oci-push-tmp-${name}" {
                type = "app";
                program = lib.getExe app;
              }
            ) config.oci.internal.pushTmpOCIApps;
          };
          mergeMultiArchApps = mkOption {
            description = "Apps to merge architecture-specific images into multi-arch manifest lists.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = lib.pipe config.oci.containers [
              (attrsets.filterAttrs (_: c: c.multiArch.enabled))
              (attrsets.mapAttrs' (
                containerId: containerConfig:
                attrsets.nameValuePair containerId (
                  ociLib.mkMergeMultiArchApp {
                    perSystemConfig = config.oci;
                    inherit containerId;
                    systems = containerConfig.multiArch.systems;
                  }
                )
              ))
            ];
          };
          prefixedMergeMultiArchApps = mkOption {
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs' (
              name: app:
              attrsets.nameValuePair "oci-merge-${name}" {
                type = "app";
                program = lib.getExe app;
              }
            ) config.oci.internal.mergeMultiArchApps;
          };
        };
      }
    );
  };
}
