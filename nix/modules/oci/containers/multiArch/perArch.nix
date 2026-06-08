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

  # Inline arch map — avoids raw `import`, values only used in lazy option defaults.
  archMap = {
    "x86_64-linux" = {
      ociArch = "amd64";
      crossPkgsAttr = "gnu64";
    };
    "aarch64-linux" = {
      ociArch = "arm64";
      crossPkgsAttr = "aarch64-multiplatform";
    };
    "armv7l-linux" = {
      ociArch = "arm";
      ociVariant = "v7";
      crossPkgsAttr = "armv7l-hf-multiplatform";
    };
    "riscv64-linux" = {
      ociArch = "riscv64";
      crossPkgsAttr = "riscv64";
    };
  };

  systemToOCIArch = system: archMap.${system}.ociArch;

  systemToOCIPlatform =
    system:
    let
      entry = archMap.${system};
      variant = entry.ociVariant or null;
    in
    if variant != null then "linux/${entry.ociArch}/${variant}" else "linux/${entry.ociArch}";

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
                  default = systemToOCIArch name;
                };

                # Computed: OCI platform string (e.g. "linux/amd64", "linux/arm/v7").
                options._platform = mkOption {
                  type = types.str;
                  readOnly = true;
                  internal = true;
                  description = "Internal: the OCI platform string.";
                  default = systemToOCIPlatform name;
                };

                # Whether this is the native (host) architecture.
                options.isNative = mkOption {
                  type = types.bool;
                  readOnly = true;
                  description = "Whether this architecture matches the current host system.";
                  default = name == system;
                };

                # Per-arch package override.
                # Native arch: defaults to the container's main package.
                # Cross arch: auto-inferred via pkgsCross.${crossPkgsAttr}.${pname}.
                #   Falls back to null if inference fails — user must set manually.
                options.package = mkOption {
                  type = types.nullOr types.package;
                  description = ''
                    Package for this architecture.

                    For the native architecture, defaults to the container's main package.
                    For cross architectures, auto-inferred from the container's package
                    via `pkgs.pkgsCross.''${crossPkgsAttr}.''${pname}`. If the package
                    is not available in pkgsCross (e.g. different attr name), set it
                    manually or use a nixpkgs overlay so the package is available in
                    all cross-compilation sets.
                  '';
                  default =
                    let
                      crossPkgsAttr = archMap.${name}.crossPkgsAttr or null;
                      mainPkg = containerConfig.package;
                      pname = mainPkg.pname or null;
                      crossPkgSet = if crossPkgsAttr != null then pkgs.pkgsCross.${crossPkgsAttr} or null else null;
                      hasAttr = crossPkgSet != null && pname != null && builtins.hasAttr pname crossPkgSet;
                    in
                    if name == system then
                      mainPkg
                    else if mainPkg == null then
                      null
                    else if hasAttr then
                      crossPkgSet.${pname}
                    else
                      null;
                  defaultText = lib.literalExpression "auto-inferred via pkgsCross (native) or null (fallback)";
                };

                # Per-arch dependencies override.
                # Native: inherits container deps. Cross: auto-inferred per dep.
                options.dependencies = mkOption {
                  type = types.listOf types.package;
                  description = ''
                    Dependencies for this architecture.
                    For native arch, defaults to the container's dependencies.
                    For cross arches, each dependency is auto-inferred via
                    pkgsCross when possible. Dependencies that fail inference
                    are silently dropped — override manually if needed.
                  '';
                  default =
                    let
                      crossPkgsAttr = archMap.${name}.crossPkgsAttr or null;
                      containerDeps = containerConfig.dependencies or [ ];
                      crossPkgSet = if crossPkgsAttr != null then pkgs.pkgsCross.${crossPkgsAttr} or null else null;
                      inferDep =
                        dep:
                        let
                          pname = dep.pname or null;
                          hasAttr = crossPkgSet != null && pname != null && builtins.hasAttr pname crossPkgSet;
                        in
                        if hasAttr then crossPkgSet.${pname} else null;
                    in
                    if name == system then
                      containerDeps
                    else
                      builtins.filter (d: d != null) (map inferDep containerDeps);
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
