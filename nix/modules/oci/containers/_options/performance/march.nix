# Shared: container-level microarchitecture targeting (sugar).
#
# This is container-level sugar that flows down to the per-arch
# config via mkDefault. The canonical per-arch option lives in
# _archOptions/performance/march.nix.
#
# For single-arch containers, this is all you need.
# For multi-arch, override per-arch via archConfigs.
{
  lib,
  pkgs,
  ...
}:
let
  example = "x86-64-v3";
in
{
  options.performance.march = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Target CPU microarchitecture level for package compilation.

      Sets `-march` and `-mtune` for all packages in this container.
      For multi-arch containers, this sets the default for the host
      architecture -- override per-arch via `archConfigs`.

      Valid values depend on the target system:
      - **x86_64-linux**: `"x86-64"`, `"x86-64-v2"`, `"x86-64-v3"`, `"x86-64-v4"`
      - **aarch64-linux**: `"armv8-a"`, `"armv8.2-a"`, `"armv8.4-a"`, `"armv9-a"`

      Query valid values: `config.lib.oci.systemMarchValues "x86_64-linux"`

      > **Warning**: loses the Hydra binary cache -- everything rebuilds
      > locally. Use `performance.hwcaps` for multi-level support without
      > full cache loss.
    '';
    inherit example;
  };

  config._tests.performance-march = {
    level = "eval";
    default = {
      package = pkgs.hello;
      performance.enable = true;
    };
    override = {
      package = pkgs.hello;
      performance.enable = true;
      performance.march = example;
    };
  };
}
