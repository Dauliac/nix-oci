# OCI mkNixOSRoot - Build container root filesystem from NixOS eval
#
# Replaces mkRoot by extracting shadow files, nsswitch, SSL certs,
# and home directory from the NixOS eval instead of hand-generating them.
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkNixOSRoot = {
        type = lib.types.functionTo lib.types.package;
        description = "Build container root filesystem from NixOS eval output";
        fn =
          {
            nixosEval,
            package ? null,
            dependencies ? [ ],
            user,
          }:
          let
            etc = nixosEval.environment.etc;

            # Generate shadow files from NixOS eval's users.users/groups
            # (NixOS doesn't put passwd/group/shadow in environment.etc —
            # those are created by an activation script we can't run)
            users = nixosEval.users.users;
            groups = nixosEval.users.groups;

            passwdContent = lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                name: u:
                let
                  gid = toString (groups.${u.group}.gid or 0);
                in
                "${name}:x:${toString u.uid}:${gid}::${u.home}:"
              ) (lib.filterAttrs (_: u: u.uid != null) users)
            );

            groupContent = lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: g: "${name}:x:${toString g.gid}:") (
                lib.filterAttrs (_: g: g.gid != null) groups
              )
            );

            shadowContent = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: "${name}:!:::::::") users);

            gshadowContent = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: "${name}:x::") groups);

            shadowFiles = [
              (pkgs.writeTextDir "etc/passwd" passwdContent)
              (pkgs.writeTextDir "etc/group" groupContent)
              (pkgs.writeTextDir "etc/shadow" shadowContent)
              (pkgs.writeTextDir "etc/gshadow" gshadowContent)
            ];

            # Extract /etc files that DO exist in environment.etc
            wantedEtcFiles = builtins.filter (n: etc ? ${n}) [
              "nsswitch.conf"
              "ssl/certs/ca-bundle.crt"
            ];
            etcFiles = map (
              name:
              let
                entry = etc.${name};
                safeName = builtins.replaceStrings [ "/" ] [ "-" ] name;
                mode = entry.mode or "0644";
                isSymlink = mode == "symlink" || mode == "direct-symlink";
              in
              pkgs.runCommand "etc-${safeName}" { } ''
                mkdir -p $out/etc/$(dirname "${name}")
                cp -L ${entry.source} $out/etc/${name}
                ${if isSymlink then "" else "chmod ${mode} $out/etc/${name}"}
              ''
            ) wantedEtcFiles;

            # Home directory from NixOS eval
            home = if user == "root" then "/root" else "/home/${user}";

            # Check if home-manager produced files
            hmActivation =
              let
                hmUsers = nixosEval.home-manager.users or { };
                hmUser = hmUsers.${user} or null;
              in
              if hmUser != null then hmUser.home.activationPackage or null else null;

            homeDir =
              if hmActivation != null then
                # Home-manager generates the full home directory
                pkgs.runCommand "home-dir-hm" { } ''
                  mkdir -p $out${home}
                  # Link home-manager generated files
                  if [ -d "${hmActivation}/home-files" ]; then
                    cp -rT ${hmActivation}/home-files $out${home}
                  fi
                ''
              else
                pkgs.runCommand "home-dir" { } ''
                  mkdir -p $out${home}
                '';

            package' = if package == null then [ ] else [ package ];
          in
          pkgs.buildEnv {
            name = "root";
            paths =
              package'
              ++ shadowFiles
              ++ etcFiles
              ++ dependencies
              ++ [
                homeDir
                (pkgs.runCommand "fhs-tmp" { } "mkdir -p $out/tmp $out/var/tmp")
              ];
            pathsToLink = [
              "/bin"
              "/lib"
              "/etc"
              "/home"
              "/root"
              "/tmp"
              "/var"
            ];
          };
      };
    };
}
