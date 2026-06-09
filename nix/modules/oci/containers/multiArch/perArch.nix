# OCI perArch - per-architecture module collector inside each container
#
# Each container gets:
#   - `perArch`     — a deferred module type that collects per-arch option contributions
#   - `archConfigs` — attrsOf perArch, always seeded with at least the host system
#
# Module authors contribute per-arch options via the top-level `oci.perArchitecture`
# (preferred) or via `perArch` inside a `perContainer` contribution:
#
#   # Preferred: top-level (parallel to perContainer)
#   oci.perArchitecture = { name, containerConfig, ... }: {
#     options.myArchOption = mkOption { ... };
#   };
#
#   # Alternative: nested inside perContainer
#   oci.perContainer = { ... }: {
#     perArch = { ... }: { options.myArchOption = mkOption { ... }; };
#   };
#
# Users override individual arch configs declaratively:
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

  # Static per-arch option modules (same pattern as optionModules in perContainer.nix).
  # These are always included in the perArch submodule type, making them
  # visible to nixosOptionsDoc.
  archOptionModules = [
    ../_archOptions/performance/march.nix
    ../_archOptions/performance/hwcaps.nix
  ];

  mkPerArchType = module: deferredModuleWith { staticModules = [ module ] ++ archOptionModules; };
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
          perSystemConfig,
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
                # Cross arch: auto-inferred via pkgsCross (crossBuild) or
                #   target-system nixpkgs (emulatedBuild via QEMU binfmt).
                #   Falls back to null if inference fails — user must set manually.
                options.package = mkOption {
                  type = types.nullOr types.package;
                  description = ''
                    Package for this architecture.

                    For the native architecture, defaults to the container's main package.

                    For cross architectures with `crossBuild.enable`, auto-inferred from
                    the container's package via `pkgs.pkgsCross.''${crossPkgsAttr}.''${pname}`.

                    For emulated architectures with `emulatedBuild.enable`, auto-inferred
                    by importing nixpkgs for the target system and looking up the pname.
                    The build runs under QEMU binfmt emulation.

                    If auto-inference fails, set the package manually.
                  '';
                  default =
                    let
                      mainPkg = containerConfig.package;
                      pname = mainPkg.pname or null;

                      # Cross-compilation inference (pkgsCross)
                      crossPkgsAttr = archMap.${name}.crossPkgsAttr or null;
                      crossPkgSet = if crossPkgsAttr != null then pkgs.pkgsCross.${crossPkgsAttr} or null else null;
                      hasCrossAttr = crossPkgSet != null && pname != null && builtins.hasAttr pname crossPkgSet;

                      # Emulated build inference (target-system nixpkgs via QEMU binfmt)
                      emulatedEnabled = containerConfig.multiArch.emulatedBuild.enable or false;
                      emulatedPkgs = import pkgs.path { system = name; };
                      hasEmulatedAttr = pname != null && builtins.hasAttr pname emulatedPkgs;
                    in
                    if name == system then
                      mainPkg
                    else if mainPkg == null then
                      null
                    else if emulatedEnabled then
                      if hasEmulatedAttr then emulatedPkgs.${pname} else null
                    else if hasCrossAttr then
                      crossPkgSet.${pname}
                    else
                      null;
                  defaultText = lib.literalExpression "auto-inferred via pkgsCross, emulated nixpkgs, or null (fallback)";
                };

                # Per-arch dependencies override.
                # Native: inherits container deps. Cross: auto-inferred per dep.
                options.dependencies = mkOption {
                  type = types.listOf types.package;
                  description = ''
                    Dependencies for this architecture.
                    For native arch, defaults to the container's dependencies.
                    For cross arches, each dependency is auto-inferred via
                    pkgsCross (crossBuild) or target-system nixpkgs (emulatedBuild).
                    Dependencies that fail inference are silently dropped —
                    override manually if needed.
                  '';
                  default =
                    let
                      containerDeps = containerConfig.dependencies or [ ];

                      # Emulated build: import target nixpkgs
                      emulatedEnabled = containerConfig.multiArch.emulatedBuild.enable or false;
                      emulatedPkgs = import pkgs.path { system = name; };

                      # Cross build: pkgsCross
                      crossPkgsAttr = archMap.${name}.crossPkgsAttr or null;
                      crossPkgSet = if crossPkgsAttr != null then pkgs.pkgsCross.${crossPkgsAttr} or null else null;

                      inferDep =
                        dep:
                        let
                          pname = dep.pname or null;
                        in
                        if emulatedEnabled then
                          if pname != null && builtins.hasAttr pname emulatedPkgs then emulatedPkgs.${pname} else null
                        else
                          let
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

              Prefer contributing via the top-level `oci.perArchitecture` (parallel to
              `oci.perContainer`) unless you need container-level context at definition time.

              The module receives these special arguments:
              - `name`            : the system string (key in archConfigs attrsOf)
              - `containerConfig` : the container's evaluated config
              - `containerId`     : the container's attribute name
              - `system`          : current host system
              - `pkgs`            : nixpkgs for current host system
            '';
            apply =
              modules:
              let
                # Merge modules from the top-level oci.perArchitecture collector
                perArchitectureModules = perSystemConfig.oci._perArchitectureModules or [ ];
              in
              types.submoduleWith {
                modules = modules ++ perArchitectureModules;
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

              Always contains at least the host system, even in single-arch mode.
              Auto-populated from the `multiArch.systems` list when multi-arch is
              enabled. Override individual arch settings by addressing the key directly:

                oci.containers.myApp.archConfigs."aarch64-linux".package = crossPkg;
            '';
          };

          # Always seed archConfigs with at least the host system.
          # When multiArch.systems is non-empty, those systems are used instead.
          # This ensures per-arch options (performance.march, etc.) are always
          # accessible, even in single-arch mode.
          config.archConfigs = lib.genAttrs (
            if config.multiArch.systems != [ ] then config.multiArch.systems else [ system ]
          ) (_: { });
        };
    };
}
