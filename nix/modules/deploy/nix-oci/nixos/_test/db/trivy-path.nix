{ lib, ... }:
{
  options.testing.db.trivy.path = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = "Pinned Trivy vulnerability DB path. Null = skip Trivy in tests.";
  };
}
