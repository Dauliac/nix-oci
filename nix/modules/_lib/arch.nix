# Centralized architecture mapping — single source of truth.
#
# Maps Nix system strings to OCI platform architectures and nixpkgs
# cross-compilation package set names.
#
# Consumed by:
#   - flake-parts multi-arch lib (multi-arch/lib.nix, crossBuildLib.nix)
#   - internal/packages.nix, internal/crossBuildPackages.nix
#   - perArch deferred module
#
# Usage:
#   let archDefs = import ./_lib/arch.nix; in ...
let
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
in
{
  inherit archMap;

  # List of all supported system strings (for types.enum).
  supportedSystems = builtins.attrNames archMap;

  # system string → OCI arch string (e.g. "x86_64-linux" → "amd64").
  systemToOCIArch = system: archMap.${system}.ociArch;

  # system string → OCI platform string (e.g. "linux/amd64", "linux/arm/v7").
  systemToOCIPlatform =
    system:
    let
      entry = archMap.${system};
      variant = entry.ociVariant or null;
    in
    if variant != null then "linux/${entry.ociArch}/${variant}" else "linux/${entry.ociArch}";
}
