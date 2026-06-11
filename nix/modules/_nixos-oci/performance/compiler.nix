{ lib, ... }:
{
  options.oci.container.performance.compiler = lib.mkOption {
    type = lib.types.submodule {
      options = {
        lto = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "thin"
              "full"
            ]
          );
          default = null;
          description = "Link-Time Optimization mode.";
        };
        optimizeLevel = lib.mkOption {
          type = lib.types.enum [
            "O2"
            "O3"
            "Os"
          ];
          default = "O2";
          description = "GCC/Clang optimization level.";
        };
        noSemanticInterposition = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Pass -fno-semantic-interposition.";
        };
      };
    };
    default = { };
    description = "Compiler optimization flags.";
  };
}
