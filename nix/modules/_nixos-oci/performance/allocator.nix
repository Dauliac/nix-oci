{ lib, ... }:
{
  options.oci.container.performance.allocator = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "mimalloc"
        "tcmalloc"
        "jemalloc"
        "snmalloc"
      ]
    );
    default = null;
    description = "Alternative memory allocator injected via LD_PRELOAD.";
  };
}
