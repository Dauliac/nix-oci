{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
  inherit (lib) mkOption types attrsets;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      { config, ... }:
      let
        ociLib = config.lib.oci or { };
      in
      {
        options.oci.internal = {
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
        };
      }
    );
  };
}
