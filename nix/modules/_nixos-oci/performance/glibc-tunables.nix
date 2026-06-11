{ lib, ... }:
{
  options.oci.container.performance.glibcTunables = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "glibc tunables for GLIBC_TUNABLES env var.";
  };
}
