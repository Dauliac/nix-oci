# OCI perTag - per-tag module collector inside each container
#
# Mirrors the perContainer pattern one level deeper. Each container gets:
#   - `perTag`    — a deferred module type that collects per-tag option contributions
#   - `tagConfigs` — attrsOf perTag, auto-populated from the `tags` list
#
# Module authors contribute per-tag options by adding to `perTag` inside
# their `perContainer` contribution:
#
#   oci.perContainer = { name, config, ... }: {
#     options.perTag = mkOption {
#       type = mkPerTagType ({ tag, containerConfig, ... }: {
#         options.myTagOption = mkOption { ... };
#       });
#     };
#   };
#
# Users can override individual tag configs declaratively:
#
#   oci.containers.myApp.tagConfigs."latest".push = false;
#
# The module receives these special arguments:
#   - `name`            : the tag literal (attribute key from attrsOf)
#   - `containerConfig` : the container's evaluated config
#   - `containerId`     : the container's attribute name
#   - `system`          : current system (passed through from perContainer)
#   - `pkgs`            : nixpkgs (passed through from perContainer)
{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkOptionType
    defaultFunctor
    isAttrs
    isFunction
    showOption
    types
    ;

  # Same deferredModuleWith pattern as perContainer.nix — collects module
  # contributions and returns them as a list when merged.
  deferredModuleWith =
    {
      staticModules ? [ ],
    }:
    mkOptionType {
      name = "deferredModule";
      description = "per-tag module";
      descriptionClass = "noun";
      check = x: isAttrs x || isFunction x || lib.types.path.check x;
      merge =
        loc: defs:
        staticModules
        ++ map (
          def: lib.setDefaultModuleLocation "${def.file}, via option ${showOption loc}" def.value
        ) defs;
      inherit (types.submoduleWith { modules = staticModules; }) getSubOptions getSubModules;
      substSubModules =
        m:
        deferredModuleWith {
          staticModules = m;
        };
      functor = defaultFunctor "deferredModuleWith" // {
        type = deferredModuleWith;
        payload = {
          inherit staticModules;
        };
        binOp = lhs: rhs: {
          staticModules = lhs.staticModules ++ rhs.staticModules;
        };
      };
    };

  mkPerTagType = module: deferredModuleWith { staticModules = [ module ]; };
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        {
          name,
          config,
          system,
          pkgs,
          ...
        }:
        {
          options.perTag = mkOption {
            type = mkPerTagType (
              {
                name,
                containerConfig,
                ...
              }:
              {
                # Internal: mirrors _containerName from perContainer.
                options._tagName = mkOption {
                  type = types.str;
                  internal = true;
                  description = "Internal: the tag literal.";
                };
                config._tagName = lib.mkDefault name;

                # Whether this tag is the head of the container's tags list.
                # Replaces the ad-hoc `tag == builtins.head tags` re-derivation
                # that was scattered in internal/packages.nix.
                options.primary = mkOption {
                  type = types.bool;
                  readOnly = true;
                  description = "Whether this is the primary (first) tag in the container's tags list.";
                  default = name == builtins.head containerConfig.tags;
                };

                # Per-tag push flag. Inherits the container-level push flag
                # so the default behaviour is unchanged, but individual tags
                # can be opted out:
                #   oci.containers.myApp.tagConfigs."rc-1".push = false;
                options.push = mkOption {
                  type = types.bool;
                  description = "Whether to push this specific tag to the registry. Defaults to the container-level push flag.";
                  default = containerConfig.push;
                };
              }
            );
            default = { };
            description = ''
              Per-tag module definition.

              Multiple modules can contribute to this option. Each contribution
              is a module evaluated for every tag with tag-specific context.

              The module receives these special arguments:
              - `name`            : the tag literal (key in tagConfigs attrsOf)
              - `containerConfig` : the container's evaluated config
              - `containerId`     : the container's attribute name
              - `system`          : current system
              - `pkgs`            : nixpkgs
            '';
            apply =
              modules:
              types.submoduleWith {
                inherit modules;
                specialArgs = {
                  inherit system pkgs;
                  containerConfig = config;
                  containerId = name;
                };
                class = "perTag";
              };
          };

          options.tagConfigs = mkOption {
            type = types.attrsOf config.perTag;
            description = ''
              Per-tag evaluated configs, keyed by tag literal.

              Auto-populated from the `tags` list — no manual declaration needed.
              Override individual tag settings by addressing the key directly:

                oci.containers.myApp.tagConfigs."latest".push = false;
            '';
          };

          # Seed tagConfigs with one entry per declared tag as an actual
          # config definition (not just `default =`). This is intentional:
          # `default` is discarded as soon as any user definition exists, so
          # a plain default would cause user overrides like
          # `tagConfigs."stable".push = false` to wipe out all other tags.
          # Using `config.tagConfigs` makes it a real definition that
          # `types.attrsOf` merges with user definitions key-by-key.
          config.tagConfigs = lib.genAttrs config.tags (_: { });
        };
    };
}
