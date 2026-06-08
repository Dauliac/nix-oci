# Register architecture mapping functions in flake-parts nix-lib.
#
# Provides `config.lib.oci.{archMap,supportedSystems,systemToOCIArch,systemToOCIPlatform}`.
{ ... }:
let
  archMap = {
    "x86_64-linux" = {
      ociArch = "amd64";
      crossPkgsAttr = "gnu64";
      microarch = {
        hwcapsSupported = true;
        hwcapsLevels = [
          "x86-64-v2"
          "x86-64-v3"
          "x86-64-v4"
        ];
        marchValues = [
          "x86-64"
          "x86-64-v2"
          "x86-64-v3"
          "x86-64-v4"
        ];
        defaultHwcaps = [ "x86-64-v3" ];
      };
    };
    "aarch64-linux" = {
      ociArch = "arm64";
      crossPkgsAttr = "aarch64-multiplatform";
      microarch = {
        hwcapsSupported = false;
        hwcapsLevels = [ ];
        marchValues = [
          "armv8-a"
          "armv8.2-a"
          "armv8.4-a"
          "armv9-a"
        ];
        defaultHwcaps = [ ];
      };
    };
    "armv7l-linux" = {
      ociArch = "arm";
      ociVariant = "v7";
      crossPkgsAttr = "armv7l-hf-multiplatform";
      microarch = {
        hwcapsSupported = false;
        hwcapsLevels = [ ];
        marchValues = [ "armv7-a" ];
        defaultHwcaps = [ ];
      };
    };
    "riscv64-linux" = {
      ociArch = "riscv64";
      crossPkgsAttr = "riscv64";
      microarch = {
        hwcapsSupported = false;
        hwcapsLevels = [ ];
        marchValues = [
          "rv64gc"
          "rv64gcv"
        ];
        defaultHwcaps = [ ];
      };
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
            Each entry has `ociArch`, `crossPkgsAttr`, optional `ociVariant`,
            and `microarch` with `hwcapsSupported`, `hwcapsLevels`,
            `marchValues`, `defaultHwcaps`.
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

        systemMicroarch = {
          type = lib.types.functionTo lib.types.attrs;
          description = ''
            Get microarchitecture metadata for a Nix system string.
            Returns `{ hwcapsSupported, hwcapsLevels, marchValues, defaultHwcaps }`.
          '';
          fn = system: archMap.${system}.microarch;
        };

        systemMarchValues = {
          type = lib.types.functionTo (lib.types.listOf lib.types.str);
          description = "Valid `-march` values for a given system.";
          fn = system: archMap.${system}.microarch.marchValues;
        };

        systemHwcapsLevels = {
          type = lib.types.functionTo (lib.types.listOf lib.types.str);
          description = "Valid glibc-hwcaps levels for a given system.";
          fn = system: archMap.${system}.microarch.hwcapsLevels;
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
