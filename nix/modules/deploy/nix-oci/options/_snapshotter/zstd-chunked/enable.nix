# oci.snapshotter.zstdChunked.enable — zstd:chunked lazy-pulling for Podman/CRI-O.
#
# Enables partial image pulls in Podman by setting
# pull_options.enable_partial_images in containers/storage.conf.
# This is the Podman/CRI-O equivalent of eStargz — it uses
# zstd compression with a chunk-level TOC for lazy fetching.
#
# Requires the podman backend (native containers/storage feature).
{ lib, ... }:
{
  options.zstdChunked.enable = lib.mkEnableOption "zstd:chunked lazy-pulling (Podman/CRI-O only)";
}
