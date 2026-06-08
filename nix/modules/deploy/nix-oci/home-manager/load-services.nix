# Home-manager: systemd user load services using nix2container passthru copy scripts.
#
# Rootless podman needs `newuidmap`/`newgidmap` (from `shadow`) for user
# namespace UID/GID mapping. The nix2container passthru script doesn't
# include these, so we prepend them to PATH via the systemd environment.
{ ... }:
{
  flake.modules.homeManager.nix-oci-load-services =
    {
      config,
      lib,
      pkgs,
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
              # Rootless podman needs setuid newuidmap/newgidmap from NixOS wrappers
              Environment = [ "PATH=/run/wrappers/bin:/run/current-system/sw/bin" ];
              ExecStart = "${copyScript}/bin/${copyScript.name}";
            };
          }
        ) cfg.containers;
      };
    };
}
