# Register architecture mapping functions in flake-parts nix-lib.
#
# Provides `config.lib.oci.{archMap,supportedSystems,systemToOCIArch,systemToOCIPlatform}`.
{ ... }:
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
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci = {
        archMap = {
          type = lib.types.attrs;
          description = ''
            Map from Nix system strings to OCI platform metadata.
            Each entry has `ociArch`, `crossPkgsAttr`, and optional `ociVariant`.
          '';
          fn = archMap;
        };

        supportedSystems = {
          type = lib.types.listOf lib.types.str;
          description = "List of Nix system strings with OCI architecture mappings.";
          fn = builtins.attrNames archMap;
        };

        systemToOCIArch = {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Convert a Nix system string to its OCI architecture string.
            Example: `"x86_64-linux"` → `"amd64"`.
          '';
          fn = system: archMap.${system}.ociArch;
        };

        systemToOCIPlatform = {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Convert a Nix system string to its OCI platform string.
            Example: `"x86_64-linux"` → `"linux/amd64"`.
          '';
          fn =
            system:
            let
              entry = archMap.${system};
              variant = entry.ociVariant or null;
            in
            if variant != null then "linux/${entry.ociArch}/${variant}" else "linux/${entry.ociArch}";
        };
      };
    };
}
