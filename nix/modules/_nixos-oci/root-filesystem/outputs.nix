{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
in
{
  options.oci.lib.mkHomeDirDrv = lib.mkOption {
    type = lib.types.unspecified;
    internal = true;
    readOnly = true;
    description = "Home directory derivation, with home-manager files if available.";
    default =
      let
        homeDir = config.oci.lib.homeDir;
        hmActivation =
          let
            hmUsers = config.home-manager.users or { };
            hmUser = hmUsers.${cfg.user} or null;
          in
          if hmUser != null then hmUser.home.activationPackage or null else null;
      in
      if hmActivation != null then
        pkgs.runCommand "home-dir-hm" { } ''
          mkdir -p $out${homeDir}
          # home-files is typically a symlink to home-manager-files in the store.
          # -L dereferences the top-level symlink so cp sees the directory contents.
          if [ -d "${hmActivation}/home-files" ] || [ -L "${hmActivation}/home-files" ]; then
            cp -rLT ${hmActivation}/home-files $out${homeDir}
          fi
        ''
      else
        pkgs.runCommand "home-dir" { } "mkdir -p $out${homeDir}";
  };

  options.oci.container._output.rootFilesystem = lib.mkOption {
    type = lib.types.package;
    internal = true;
    readOnly = true;
    description = "Complete root filesystem (shadow + etc + deps + home).";
    default =
      let
        package' = if cfg.package != null then [ cfg.package ] else [ ];
      in
      pkgs.buildEnv {
        name = "root";
        paths =
          package'
          ++ cfg.extraPackages
          ++ cfg._output.shadowFiles
          ++ cfg._output.etcFiles
          ++ cfg.dependencies
          ++ [
            config.oci.lib.mkHomeDirDrv
            (pkgs.runCommand "fhs-tmp" { } "mkdir -p $out/tmp $out/var/tmp")
          ];
        pathsToLink = [
          "/bin"
          "/etc"
          "/home"
          "/root"
          "/tmp"
          "/var"
        ]
        # When building on a base image, do NOT link /lib — modern distros
        # use /lib → /usr/lib (merged-usr). A real /lib directory from
        # buildEnv would shadow that symlink, breaking the base image's
        # dynamically-linked binaries. Nix packages use RPATH and don't
        # need /lib.
        ++ lib.optionals (!cfg.fromImageEnabled) [ "/lib" ];
        # Dereference symlinks under /etc so tools like Dockle that
        # inspect the Docker archive tar can read passwd/shadow/group
        # instead of seeing dangling Nix store symlinks.
        postBuild = ''
          if [ -d "$out/etc" ]; then
            find "$out/etc" -type l | while read -r link; do
              target="$(readlink -f "$link")"
              if [ -f "$target" ]; then
                rm "$link"
                cp "$target" "$link"
              fi
            done
          fi
        '';
      };
  };
}
