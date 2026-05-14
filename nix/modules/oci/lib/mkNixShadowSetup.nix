# OCI mkNixShadowSetup - Build shadow files for containers with nested Nix
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkNixShadowSetup = {
        type = lib.types.functionTo (lib.types.listOf lib.types.package);
        description = "Build passwd, shadow, group, and gshadow files for containers that run nested Nix";
        fn =
          {
            # Optional non-root container user. When set, an entry is
            # added to passwd/group/shadow so the container can run as
            # this user alongside the nixbld build users.
            user ? null,
            uid ? 4000,
            gid ? uid,
            home ? if user != null then "/home/${user}" else "/root",
          }:
          let
            numBuildUsers = 32;
            hasUser = user != null && user != "root";
            userPasswd = lib.optionalString hasUser ''
              ${user}:x:${toString uid}:${toString gid}::${home}:${pkgs.bash}/bin/bash
            '';
            userGroup = lib.optionalString hasUser ''
              ${user}:x:${toString gid}:
            '';
            userShadow = lib.optionalString hasUser ''
              ${user}:!:::::::
            '';
            userGshadow = lib.optionalString hasUser ''
              ${user}:x::
            '';
          in
          with pkgs;
          [
            (writeTextDir "etc/passwd" ''
              root:x:0:0:System administrator:/root:${pkgs.bash}/bin/bash
              nobody:x:65534:65534:Unprivileged account (don't use!):/var/empty:${pkgs.shadow}/bin/nologin
              ${lib.concatMapStrings (nixbldIndex: ''
                nixbld${toString nixbldIndex}:x:${toString (30000 + nixbldIndex)}:30000:Nix build user ${toString nixbldIndex}:/var/empty:/bin/false
              '') (builtins.genList (nixbldIndex: nixbldIndex + 1) numBuildUsers)}${userPasswd}'')
            (writeTextDir "etc/group" ''
              root:x:0:root
              nobody:x:65534:nobody
              nixbld:x:30000:${
                lib.concatStringsSep "," (
                  map (nixbldIndex: "nixbld${toString nixbldIndex}") (
                    builtins.genList (nixbldIndex: nixbldIndex + 1) numBuildUsers
                  )
                )
              }
              ${userGroup}'')
            (writeTextDir "etc/shadow" ''
              root:!x:::::::
              nobody:!:::::::
              ${lib.concatMapStrings (nixbldIndex: ''
                nixbld${toString nixbldIndex}:!:::::::
              '') (builtins.genList (nixbldIndex: nixbldIndex + 1) numBuildUsers)}${userShadow}'')
            (writeTextDir "etc/gshadow" ''
              root:x::
              nobody:x::
              nixbld:x::
              ${userGshadow}'')
          ];
      };
    };
}
