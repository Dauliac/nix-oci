{ lib, ... }:
{
  options.ioWeight = lib.mkOption {
    type = lib.types.nullOr (lib.types.ints.between 1 10000);
    default = null;
    description = ''
      Proportional I/O share (`io.weight`). Default is 100.
      Higher weight = more I/O bandwidth when contending with peers.

      Translated to systemd `IOWeight=` / `--blkio-weight`.
    '';
    example = 500;
  };
}
