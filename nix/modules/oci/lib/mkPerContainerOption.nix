# mkPerContainerOption - Creates an option for collecting per-container modules
#
# This implements the flake-parts pattern for per-container configuration.
# Like mkPerSystemOption, it creates a deferredModule type that collects
# module contributions from multiple files.
#
# The collected modules are evaluated for EACH container with container-specific
# context (containerName, container config, etc.).
#
# Usage pattern:
#
#   # In any module - define options and config for perContainer
#   config.perSystem = { ... }: {
#     oci.perContainer = mkPerContainerOption { containerName, config, ... }: {
#       # Options available for all containers
#       options.tag = mkOption { ... };
#
#       # Config applied to all containers (use config. prefix)
#       config.isRoot = lib.mkDefault false;
#     };
#   };
#
# Multiple files can declare oci.perContainer = mkPerContainerOption(...)
# and the modules will be merged together.
{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkOptionType
    defaultFunctor
    isAttrs
    isFunction
    showOption
    ;
  inherit (lib.types) path submoduleWith;

  # Deferred module type that collects contributions (same as flake-parts)
  # Returns a list of modules when merged.
  deferredModuleWith =
    {
      staticModules ? [ ],
    }:
    mkOptionType {
      name = "deferredModule";
      description = "per-container module";
      descriptionClass = "noun";
      check = x: isAttrs x || isFunction x || path.check x;
      merge =
        loc: defs:
        staticModules
        ++ map (
          def: lib.setDefaultModuleLocation "${def.file}, via option ${showOption loc}" def.value
        ) defs;
      inherit (submoduleWith { modules = staticModules; }) getSubOptions getSubModules;
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

  # Create the per-container type with a static module
  mkPerContainerType = module: deferredModuleWith { staticModules = [ module ]; };

  # Create an option declaration suitable for type-merging into perContainer
  mkPerContainerOption =
    module:
    mkOption {
      type = mkPerContainerType module;
    };
in
{
  # Export as flake-level lib functions
  config.lib.flake = {
    ociMkPerContainerOption = {
      type = lib.types.functionTo lib.types.unspecified;
      description = "Create an option declaration for per-container modules";
      fn = mkPerContainerOption;
    };
    ociMkPerContainerType = {
      type = lib.types.functionTo lib.types.unspecified;
      description = "Create the per-container deferred module type";
      fn = mkPerContainerType;
    };
  };
}
