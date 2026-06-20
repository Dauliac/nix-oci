# OCI perContainer - base module for per-container option collection
#
# This implements the flake-parts pattern for per-container configuration.
# Other modules contribute container options via:
#
#   config.perSystem = { ... }: {
#     oci.perContainer = { name, config, ... }: {
#       options.myOption = mkOption { ... };
#     };
#   };
#
# Users set container config via oci.containers (same as before), and the
# container submodule options are collected from multiple files.
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
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
  cfg = config;
  # Pure function — nix-lib config.lib.* is unavailable at option-definition time.
  discoverModules = import ../../../lib/discoverModules.nix { inherit lib; };

  # Deferred module type that collects contributions
  deferredModuleWith =
    {
      staticModules ? [ ],
    }:
    mkOptionType {
      name = "deferredModule";
      description = "per-container module";
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

  # All option-declaration-only modules: container-specific (_options/) + shared (_oci/).
  # Auto-discovered via nix-lib discoverModules so new files are picked up automatically.
  # Including them as staticModules makes getSubOptions visible to nixosOptionsDoc.
  optionModules = discoverModules ./_options ++ discoverModules ../_oci;

  mkPerContainerType = module: deferredModuleWith { staticModules = [ module ] ++ optionModules; };
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      system,
      pkgs,
      ...
    }:
    {
      options.oci = {
        # perContainer - collects module definitions from multiple files
        # These modules define the options available on each container
        perContainer = mkOption {
          type = mkPerContainerType (
            { name, ... }:
            {
              # Base container options - name is always available (from types.attrsOf)
              options._containerName = mkOption {
                type = types.str;
                internal = true;
                description = "Internal: the container attribute name.";
              };
              config._containerName = lib.mkDefault name;
            }
          );
          default = { };
          description = ''
            Per-container module definition.

            Multiple modules can contribute to this option. Each contribution is a
            module that will be evaluated for every container with container-specific
            context.

            The module receives these special arguments:
            - `name`: the attribute name of the container (from types.attrsOf)
            - `config`: the container's config (for reading within the module)
            - `globalConfig`: the top-level flake config
            - `perSystemConfig`: the perSystem config
            - `system`: the current system
            - `pkgs`: nixpkgs for current system
            - `lib`: nixpkgs lib
          '';
          # The apply function creates a submodule type from the collected modules.
          # _collectedModules is attached for flavour expansion (so synthetic
          # containers can be evaluated through the same module pipeline).
          apply =
            modules:
            types.submoduleWith {
              modules = modules;
              specialArgs = {
                inherit system pkgs;
                globalConfig = cfg;
                perSystemConfig = config;
              };
              class = "perContainer";
            }
            // {
              _collectedModules = modules;
            };
        };

        # containers - user-facing container definitions
        # The submodule type is dynamically constructed from perContainer modules
        containers = mkOption {
          type = types.attrsOf (config.oci.perContainer);
          default = { };
          description = "Container definitions. Each key is a container name.";
          example = lib.literalExpression ''
            {
              my-app = {
                package = pkgs.hello;
                dependencies = [ pkgs.bash ];
              };
            }
          '';
        };
      };
    }
  );
}
