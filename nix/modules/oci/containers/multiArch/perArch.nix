# OCI perArch - per-architecture module collector inside each container
#
# Mirrors the perTag pattern one level deeper. Each container gets:
#   - `perArch`     — a deferred module type that collects per-arch option contributions
#   - `archConfigs` — attrsOf perArch, auto-populated from `multiArch.systems`
#
# Module authors contribute per-arch options by adding to `perArch` inside
# their `perContainer` contribution:
#
#   oci.perContainer = { name, config, ... }: {
#     oci.perArch = { ... }: {
#       options.myArchOption = mkOption { ... };
#     };
#   };
#
# Users can override individual arch configs declaratively:
#
#   oci.containers.myApp.archConfigs."aarch64-linux".package = crossPkg;
#
# The module receives these special arguments:
#   - `name`            : the system string (attribute key from attrsOf)
#   - `containerConfig` : the container's evaluated config
#   - `containerId`     : the container's attribute name
#   - `system`          : current host system (passed through from perContainer)
#   - `pkgs`            : nixpkgs for current host system
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

  archDefs = import ../../../_lib/arch.nix;

  deferredModuleWith =
    {
      staticModules ? [ ],
    }:
    mkOptionType {
      name = "deferredModule";
      description = "per-arch module";
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

  mkPerArchType = module: deferredModuleWith { staticModules = [ module ]; };
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
          options.perArch = mkOption {
            type = mkPerArchType (
              {
                name,
                containerConfig,
                ...
              }:
              {
                # Internal: the Nix system string for this arch entry.
                options._system = mkOption {
                  type = types.str;
                  internal = true;
                  description = "Internal: the target system string.";
                };
                config._system = lib.mkDefault name;

                # Computed: OCI architecture string (e.g. "amd64", "arm64").
                options._arch = mkOption {
                  type = types.str;
                  readOnly = true;
                  internal = true;
                  description = "Internal: the OCI architecture string.";
                  default = archDefs.systemToOCIArch name;
                };

                # Computed: OCI platform string (e.g. "linux/amd64", "linux/arm/v7").
                options._platform = mkOption {
                  type = types.str;
                  readOnly = true;
                  internal = true;
                  description = "Internal: the OCI platform string.";
                  default = archDefs.systemToOCIPlatform name;
                };

                # Whether this is the native (host) architecture.
                options.isNative = mkOption {
                  type = types.bool;
                  readOnly = true;
                  description = "Whether this architecture matches the current host system.";
                  default = name == system;
                };

                # Per-arch package override. Defaults to the container's
                # package for native arch, null for cross arches.
                options.package = mkOption {
                  type = types.nullOr types.package;
                  description = ''
                    Package for this architecture.

                    For the native architecture, defaults to the container's main package.
                    For cross architectures, must be set explicitly (e.g. via pkgsCross).
                  '';
                  default = if name == system then containerConfig.package else null;
                  defaultText = lib.literalExpression "containerConfig.package (native) or null (cross)";
                };

                # Per-arch dependencies override.
                options.dependencies = mkOption {
                  type = types.listOf types.package;
                  description = "Dependencies for this architecture. Defaults to container dependencies for native arch.";
                  default = if name == system then (containerConfig.dependencies or [ ]) else [ ];
                };
              }
            );
            default = { };
            description = ''
              Per-architecture module definition.

              Multiple modules can contribute to this option. Each contribution
              is a module evaluated for every target architecture with arch-specific context.

              The module receives these special arguments:
              - `name`            : the system string (key in archConfigs attrsOf)
              - `containerConfig` : the container's evaluated config
              - `containerId`     : the container's attribute name
              - `system`          : current host system
              - `pkgs`            : nixpkgs for current host system
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
                class = "perArch";
              };
          };

          options.archConfigs = mkOption {
            type = types.attrsOf config.perArch;
            description = ''
              Per-architecture evaluated configs, keyed by Nix system string.

              Auto-populated from the `multiArch.systems` list — no manual
              declaration needed. Override individual arch settings by
              addressing the key directly:

                oci.containers.myApp.archConfigs."aarch64-linux".package = crossPkg;
            '';
          };

          # Seed archConfigs with one entry per declared system (same pattern
          # as tagConfigs seeded from tags in perTag.nix).
          config.archConfigs = lib.genAttrs config.multiArch.systems (_: { });
        };
    };
}
