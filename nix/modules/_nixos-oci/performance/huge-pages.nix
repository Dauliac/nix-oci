{ lib, ... }:
{
  options.oci.container.performance.hugePages = lib.mkOption {
    type = lib.types.submodule {
      options = {
        thpMode = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "madvise"
              "always"
            ]
          );
          default = null;
          description = "Transparent Huge Pages mode hint.";
        };
        glibcHugetlb = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              0
              1
              2
            ]
          );
          default = null;
          description = "glibc malloc.hugetlb tunable value (0/1/2).";
        };
      };
    };
    default = { };
    description = "Huge page configuration.";
  };
}
