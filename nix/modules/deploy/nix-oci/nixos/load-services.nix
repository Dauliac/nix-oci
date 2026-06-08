# NixOS: systemd load services using nix2container passthru copy scripts.
{ ... }:
{
  flake.modules.nixos.nix-oci-load-services =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.nix-oci;
      ociLib = cfg.lib;
    in
    {
      config = lib.mkIf cfg.enable {
        systemd.services = lib.mapAttrs' (
          name: container:
          let
            copyScript = ociLib.copyScript { inherit container; };
          in
          lib.nameValuePair (ociLib.mkLoadServiceName name) {
            description = "Load nix-oci image ${container.imageRef} into ${cfg.backend}";
            after = [ "network.target" ] ++ lib.optional (cfg.backend == "docker") "docker.service";
            requires = lib.optional (cfg.backend == "docker") "docker.service";
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${copyScript}/bin/${copyScript.name}";
            };
          }
        ) cfg.containers;
      };
    };
}
