{ lib, ... }:
{
  options.oci.container.performance.glibcTunablesPreset = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "memory-constrained"
        "high-throughput"
        "balanced"
      ]
    );
    default = null;
    description = "Curated glibc tunables preset. Explicit glibcTunables override preset values.";
  };
}
