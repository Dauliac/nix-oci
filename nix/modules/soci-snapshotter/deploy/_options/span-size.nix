# services.soci-snapshotter.spanSize — SOCI index span size.
{ lib, ... }:
{
  options.services.soci-snapshotter.spanSize = lib.mkOption {
    type = lib.types.int;
    default = 4194304;
    description = ''
      Span size in bytes for SOCI index generation.
      Smaller spans enable finer-grained lazy fetching but produce
      larger indexes. Default is 4 MiB (4194304).
    '';
    example = 1048576;
  };
}
