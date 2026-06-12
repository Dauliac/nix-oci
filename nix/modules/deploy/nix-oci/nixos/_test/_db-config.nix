# NixOS config: pre-fetched vulnerability DB paths for offline testing.
{
  config,
  lib,
  ...
}:
let
  cfg = config.testing;
in
lib.mkIf cfg.enable {
  environment.sessionVariables = lib.mkMerge [
    (lib.mkIf (cfg.db.trivy.path != null) {
      TRIVY_DB_PATH = toString cfg.db.trivy.path;
    })
    (lib.mkIf (cfg.db.grype.path != null) {
      GRYPE_DB_PATH = toString cfg.db.grype.path;
    })
  ];
}
