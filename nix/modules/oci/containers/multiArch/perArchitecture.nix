# OCI perArchitecture - top-level per-architecture module collector
#
# Parallel to `oci.perContainer`: a top-level deferred module collector for
# per-architecture options. Modules contributed here are applied to every
# container's `archConfigs.${system}` entries.
#
# Module authors contribute per-arch options by adding to `oci.perArchitecture`:
#
#   config.perSystem = { ... }: {
#     oci.perArchitecture = [
#       ({ name, containerConfig, ... }: {
#         options.performance.march = mkOption { ... };
#       })
#     ];
#   };
#
# The contributed modules receive these special arguments (injected by perArch):
#   - `name`            : the target system string (e.g. "aarch64-linux")
#   - `containerConfig` : the parent container's evaluated config
#   - `containerId`     : the container's attribute name
#   - `system`          : the host build system
#   - `pkgs`            : nixpkgs for the host system
{
  flake-parts-lib,
  lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { lib, ... }:
    {
      options.oci._perArchitectureModules = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
        internal = true;
        description = ''
          Internal: per-architecture modules collected from `oci.perArchitecture`
          contributions. These modules are merged into every container's `perArch`
          submodule via the `apply` function in `perArch.nix`.

          Use `oci.perArchitecture` (the user-facing option) to contribute modules.
        '';
      };

      options.oci.perArchitecture = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
        description = ''
          Per-architecture module definitions applied to every `archConfigs` entry.

          Parallel to `oci.perContainer` — a top-level collector for per-architecture
          options. Contributed modules are evaluated for every target architecture
          within every container.

          Each module receives these special arguments:
          - `name`            : the target system string (e.g. `"aarch64-linux"`)
          - `containerConfig` : the parent container's evaluated config
          - `containerId`     : the container's attribute name
          - `system`          : the host build system
          - `pkgs`            : nixpkgs for the host system

          Example:
          ```nix
          oci.perArchitecture = [
            ({ name, containerConfig, ... }: {
              options.myArchOption = lib.mkOption { type = lib.types.str; };
            })
          ];
          ```
        '';
      };
    }
  );

  # Forward oci.perArchitecture to the internal _perArchitectureModules.
  # This indirection exists because perArch.nix reads _perArchitectureModules
  # in its apply function, and we want the public API to be oci.perArchitecture.
  config.perSystem =
    { config, ... }:
    {
      oci._perArchitectureModules = config.oci.perArchitecture;
    };
}
