{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container.performance;
in
{
  config.assertions = lib.optionals cfg.enable [
    {
      assertion = !(cfg.allocator != null && cfg.allocatorConfig != { } && cfg.allocator == "snmalloc");
      message = ''
        nix-oci: `performance.allocator = "snmalloc"` but `allocatorConfig` is set.
        snmalloc has no runtime tunables. The config keys
        ${lib.concatStringsSep ", " (lib.attrNames cfg.allocatorConfig)} will be ignored.
        Fix: remove `allocatorConfig` or switch to an allocator that supports tuning
        (jemalloc, mimalloc, tcmalloc).
      '';
    }
    {
      assertion = !(cfg.allocator == null && cfg.allocatorConfig != { });
      message = ''
        nix-oci: `performance.allocatorConfig` is set but no `allocator` is selected.
        The config keys ${lib.concatStringsSep ", " (lib.attrNames cfg.allocatorConfig)} will be ignored.
        Fix: set `performance.allocator` to one of: mimalloc, tcmalloc, jemalloc, snmalloc.
      '';
    }
    {
      assertion =
        !(cfg.glibcTunablesPreset != null && cfg.allocator != null && cfg.allocator != "jemalloc");
      message = ''
        nix-oci: `performance.glibcTunablesPreset = "${toString cfg.glibcTunablesPreset}"` tunes
        glibc's built-in malloc, but `allocator = "${toString cfg.allocator}"` replaces it via
        LD_PRELOAD. The glibc tunables will have no effect on allocations.
        Fix: remove `glibcTunablesPreset` when using a non-glibc allocator, or remove the allocator.
      '';
    }
    {
      assertion = !(cfg.glibcTunables != { } && cfg.allocator != null && cfg.allocator != "jemalloc");
      message = ''
        nix-oci: explicit `performance.glibcTunables` are set but `allocator = "${toString cfg.allocator}"`
        replaces glibc malloc via LD_PRELOAD. The glibc tunables will have no effect.
        Fix: remove `glibcTunables` when using a non-glibc allocator, or remove the allocator.
      '';
    }
  ];
}
