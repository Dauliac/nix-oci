# Per-architecture: microarchitecture targeting.
#
# Valid values depend on the target system. Validated via assertions
# in the perArchitecture contribution (multiArch/archPerformance.nix)
# using archMap.microarch.marchValues.
{ lib, ... }:
{
  options.performance.march = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Target CPU microarchitecture for this architecture's packages.

      Sets `-march` and `-mtune` for all packages built for this arch.
      Valid values depend on the target system:
      - **x86_64-linux**: `"x86-64"`, `"x86-64-v2"`, `"x86-64-v3"`, `"x86-64-v4"`
      - **aarch64-linux**: `"armv8-a"`, `"armv8.2-a"`, `"armv8.4-a"`, `"armv9-a"`

      > **Warning**: loses the Hydra binary cache. Use `performance.hwcaps`
      > for multi-level support without cache loss.
    '';
    example = "x86-64-v3";
  };
}
