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
        # Static values exposed as overridable nix-lib entries.
        # Override via nix-lib.lib.oci.archMap.fn = myCustomMap;
        archMap = {
          type = lib.types.attrs;
          description = ''
            Map from Nix system strings to OCI platform metadata.
            Each entry has `ociArch`, `crossPkgsAttr`, optional `ociVariant`,
            and `microarch` with `hwcapsSupported`, `hwcapsLevels`,
            `marchValues`, `defaultHwcaps`.
          '';
        file = "nix/modules/oci/lib/arch.nix";
          fn = archMap;
        };

        supportedSystems = {
          type = lib.types.listOf lib.types.str;
          description = "List of Nix system strings with OCI architecture mappings.";
        file = "nix/modules/oci/lib/arch.nix";
          fn = builtins.attrNames archMap;
        };

        systemToOCIArch = {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Convert a Nix system string to its OCI architecture string.
            Example: `"x86_64-linux"` → `"amd64"`.
          '';
        file = "nix/modules/oci/lib/arch.nix";
          fn = system: archMap.${system}.ociArch;
          tests = {
            "x86_64 maps to amd64" = {
              args = "x86_64-linux";
              expected = "amd64";
            };
            "aarch64 maps to arm64" = {
              args = "aarch64-linux";
              expected = "arm64";
            };
          };
        };

        systemMicroarch = {
          type = lib.types.functionTo lib.types.attrs;
          description = ''
            Get microarchitecture metadata for a Nix system string.
            Returns `{ hwcapsSupported, hwcapsLevels, marchValues, defaultHwcaps }`.
          '';
        file = "nix/modules/oci/lib/arch.nix";
          fn = system: archMap.${system}.microarch;
          tests = {
            "x86_64 supports hwcaps" = {
              args = "x86_64-linux";
              assertions = [
                {
                  name = "hwcaps supported";
                  check = result: result.hwcapsSupported == true;
                }
              ];
            };
            "aarch64 does not support hwcaps" = {
              args = "aarch64-linux";
              assertions = [
                {
                  name = "hwcaps not supported";
                  check = result: result.hwcapsSupported == false;
                }
              ];
            };
          };
        };

        systemMarchValues = {
          type = lib.types.functionTo (lib.types.listOf lib.types.str);
          description = "Valid `-march` values for a given system.";
        file = "nix/modules/oci/lib/arch.nix";
          fn = system: archMap.${system}.microarch.marchValues;
          tests = {
            "x86_64 has v2 v3 v4 levels" = {
              args = "x86_64-linux";
              assertions = [
                {
                  name = "contains x86-64-v3";
                  check = result: builtins.elem "x86-64-v3" result;
                }
              ];
            };
          };
        };

        systemHwcapsLevels = {
          type = lib.types.functionTo (lib.types.listOf lib.types.str);
          description = "Valid glibc-hwcaps levels for a given system.";
        file = "nix/modules/oci/lib/arch.nix";
          fn = system: archMap.${system}.microarch.hwcapsLevels;
          tests = {
            "x86_64 has hwcaps levels" = {
              args = "x86_64-linux";
              assertions = [
                {
                  name = "contains x86-64-v3";
                  check = result: builtins.elem "x86-64-v3" result;
                }
              ];
            };
            "aarch64 has no hwcaps" = {
              args = "aarch64-linux";
              expected = [ ];
            };
          };
        };

        systemToOCIPlatform = {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Convert a Nix system string to its OCI platform string.
            Example: `"x86_64-linux"` → `"linux/amd64"`.
          '';
        file = "nix/modules/oci/lib/arch.nix";
          fn =
            system:
            let
              entry = archMap.${system};
              variant = entry.ociVariant or null;
            in
            if variant != null then "linux/${entry.ociArch}/${variant}" else "linux/${entry.ociArch}";
          tests = {
            "x86_64 to linux/amd64" = {
              args = "x86_64-linux";
              expected = "linux/amd64";
            };
            "aarch64 to linux/arm64" = {
              args = "aarch64-linux";
              expected = "linux/arm64";
            };
            "armv7l includes variant" = {
              args = "armv7l-linux";
              expected = "linux/arm/v7";
            };
          };
        };
      };
    };
}
