# Build the container root filesystem as a single buildEnv
#
# Composes package + dependencies + configFiles + shadow setup into one
# environment with standard paths (/bin, /lib, /etc, /home).
# Used by the deploy modules for non-NixOS containers.
{ lib, ... }:
{
  nix-lib.lib.oci.mkRoot = {
    type = lib.types.functionTo lib.types.package;
    description = ''
      Build the container root filesystem as a single `buildEnv`.

      Composes package, dependencies, config files, and shadow setup
      (/etc/passwd, /etc/shadow, /etc/group) into one environment
      with `/bin`, `/lib`, `/etc`, `/home` paths.

      Used by deploy modules for non-NixOS container images.
    '';
    file = "nix/modules/oci/lib/mkRoot.nix";
    fn =
      {
        name,
        package,
        dependencies,
        configFiles,
        isRoot,
        user,
        pkgs,
      }:
      let
        mkShadowSetup =
          {
            isRoot,
            user,
            runtimeShell,
            pkgs,
          }:
          if isRoot then
            [
              (pkgs.writeTextDir "etc/passwd" "root:x:0:0::/root:${runtimeShell}\n")
              (pkgs.writeTextDir "etc/shadow" "root:!x:::::::\n")
              (pkgs.writeTextDir "etc/group" "root:x:0:\n")
            ]
          else
            [
              (pkgs.writeTextDir "etc/passwd" ''
                root:x:0:0::/root:${runtimeShell}
                ${user}:x:4000:4000::/home/${user}:${runtimeShell}
              '')
              (pkgs.writeTextDir "etc/shadow" ''
                root:!x:::::::
                ${user}:!:::::::
              '')
              (pkgs.writeTextDir "etc/group" ''
                root:x:0:
                ${user}:x:4000:
              '')
              (pkgs.runCommand "home-${user}" { } ''
                mkdir -p $out/home/${user}
              '')
            ];
      in
      pkgs.buildEnv {
        name = "oci-root-${name}";
        paths =
          (lib.optional (package != null) package)
          ++ dependencies
          ++ configFiles
          ++ (mkShadowSetup {
            inherit isRoot user pkgs;
            runtimeShell = pkgs.runtimeShell;
          });
        pathsToLink = [
          "/bin"
          "/lib"
          "/etc"
          "/home"
        ];
        ignoreCollisions = true;
      };
  };
}
