# Shared: container process startup optimization.
#
# These options reduce container cold start time by optimizing
# the dynamic linker and process initialization.
#
# References:
#   - ld.so(8): dynamic linker cache
#   - pthread_attr_setstacksize(3): thread stack size
{
  lib,
  ...
}:
let
  exampleStackSize = "512";
in
{
  options.performance.startup = lib.mkOption {
    type = lib.types.submodule {
      options = {
        ldSoCache = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Run `ldconfig` at image build time to pre-build
            `/etc/ld.so.cache` with all library paths.

            Eliminates filesystem search at process startup. Beneficial
            for containers with many shared libraries.
          '';
        };

        stackSize = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Default thread stack size override. Set via `ulimit -s` in
            the container entrypoint.

            Reducing from the default 8MB to 512KB-2MB saves significant
            virtual memory for containers with many threads.

            Format: size in KB (e.g. `"512"` for 512KB, `"2048"` for 2MB).
          '';
          example = exampleStackSize;
        };
      };
    };
    default = { };
    description = "Container process startup optimization.";
  };
}
