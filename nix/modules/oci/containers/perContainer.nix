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

  # All option-declaration-only modules in _options/.
  # Auto-discovered via readDir so new option files are picked up automatically.
  # Including them as staticModules makes getSubOptions visible to nixosOptionsDoc.
  discoverModules =
    dir:
    let
      entries = builtins.readDir dir;
      files = lib.pipe entries [
        (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name))
        builtins.attrNames
        (map (name: dir + "/${name}"))
      ];
      dirs = lib.pipe entries [
        (lib.filterAttrs (name: type: type == "directory" && !lib.hasPrefix "_" name))
        builtins.attrNames
        (lib.concatMap (name: discoverModules (dir + "/${name}")))
      ];
    in
    files ++ dirs;

  optionModules = discoverModules ./_options;

  # Test specification submodule — contributed by each option file via config._tests.
  testSpecType = types.submodule {
    options = {
      level = mkOption {
        type = types.enum [
          "eval"
          "build"
          "inspect"
          "runtime"
          "deploy"
        ];
        default = "eval";
        description = "Test depth: eval < build < inspect < runtime < deploy.";
      };

      default = mkOption {
        type = types.raw;
        default = { };
        description = "Container config using only defaults (tests the default value).";
      };

      override = mkOption {
        type = types.raw;
        default = { };
        description = "Container config with the example value applied (tests the override).";
      };

      assertions = mkOption {
        type = types.submodule {
          options = {
            imageConfig = mkOption {
              type = types.attrsOf types.raw;
              default = { };
              description = "Expected fields in the OCI image config (for inspect-level tests).";
            };
            runtime = mkOption {
              type = types.lines;
              default = "";
              description = "Python test script for VM tests (for runtime/deploy-level tests).";
            };
          };
        };
        default = { };
        description = "Assertions to verify after building/running the container.";
      };

      exampleFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Link to an examples/ file for docs cross-reference.";
      };
    };
  };

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

              # Per-option test specifications.
              # Each option file contributes via config._tests.<optionName>.
              options._tests = mkOption {
                type = types.attrsOf testSpecType;
                default = { };
                internal = true;
                visible = false;
                description = "Internal: test specifications contributed by each option file.";
              };
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
              inherit modules;
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
