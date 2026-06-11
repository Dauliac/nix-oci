{ lib, ... }:
{
  options.oci.container.performance.startup = lib.mkOption {
    type = lib.types.submodule {
      options = {
        ldSoCache = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Run ldconfig at build time to pre-build /etc/ld.so.cache.";
        };
        stackSize = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Thread stack size in KB (ulimit -s).";
        };
      };
    };
    default = { };
    description = "Startup optimization options.";
  };
}
