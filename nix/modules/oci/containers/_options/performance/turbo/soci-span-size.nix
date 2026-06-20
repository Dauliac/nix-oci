# Shared: SOCI span size for zTOC checkpoints.
#
# Controls the granularity of random-access seeking within compressed layers.
# Smaller spans = more precise seeking but larger zTOC index.
#
# References:
#   - https://github.com/awslabs/soci-snapshotter/blob/main/docs/design.md
{ lib, ... }:
let
  example = 4194304;
in
{
  options.performance.turbo.sociSpanSize = lib.mkOption {
    type = lib.types.int;
    default = 4194304;
    description = ''
      SOCI span size in bytes for zTOC checkpoint granularity.

      Controls how often deflate checkpoints are inserted in the compressed
      layer data. Smaller values allow more precise random-access seeking
      (faster individual file access) at the cost of a larger zTOC index.

      - `4194304` (4 MiB) -- default, good balance for most workloads.
      - `1048576` (1 MiB) -- finer granularity, better for many small files.
      - `8388608` (8 MiB) -- coarser, smaller index, better for large files.

      Only effective when `performance.turbo.soci = true`.
    '';
    inherit example;
  };
}
