# NixOS config: local cosign key generation for signing tests.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.testing;
in
lib.mkIf (cfg.enable && cfg.cosign.localKeys) {
  systemd.services.nix-oci-cosign-keygen = {
    description = "Generate local cosign key pair for testing";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.cosign}/bin/cosign generate-key-pair --output-key-prefix /tmp/cosign";
      Environment = "COSIGN_PASSWORD=test";
    };
  };
}
