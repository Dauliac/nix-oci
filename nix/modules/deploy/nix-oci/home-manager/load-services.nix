# Home-manager: systemd user load services using nix2container passthru copy scripts.
{ ... }:
{
  flake.modules.homeManager.nix-oci-load-services =
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
        systemd.user.services = lib.mapAttrs' (
          name: container:
          let
            copyScript = ociLib.copyScript { inherit container; };
          in
          lib.nameValuePair (ociLib.mkLoadServiceName name) {
            Unit = {
              Description = "Load nix-oci image ${container.imageRef} into ${cfg.backend}";
            };
            Install = {
              WantedBy = [ "default.target" ];
            };
            Service = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${copyScript}/bin/${copyScript.name}";
            };
          }
        ) cfg.containers;
      };
    };
}
