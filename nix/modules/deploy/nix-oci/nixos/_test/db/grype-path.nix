{ lib, ... }:
{
  options.testing.db.grype.path = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = "Pinned Grype vulnerability DB path. Null = skip Grype in tests.";
  };
}
