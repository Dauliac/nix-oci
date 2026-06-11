# Universal default bridge: propagates flake-level oci.* values
# to per-container scope at priority 1500 (below mkDefault/1000).
# Per-container computed defaults (mkDefault) override this.
# User explicit config overrides both.
{ globalConfig, ... }:
{
  config = globalConfig.lib.flake.oci.mkDefaultsRecursive 1500 globalConfig.oci;
}
