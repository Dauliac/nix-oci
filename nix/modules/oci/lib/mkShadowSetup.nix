# Generate /etc/passwd, /etc/shadow, /etc/group for the container user
#
# Creates the minimal user database files needed for a container.
# Root containers get a single root entry; non-root containers get
# root + a dedicated user with UID/GID 4000.
{ lib, ... }:
{
  nix-lib.lib.oci.mkShadowSetup = {
    type = lib.types.functionTo (lib.types.listOf lib.types.package);
    description = ''
      Generate /etc/passwd, /etc/shadow, /etc/group derivations for a container.

      Root containers get a single `root` entry.
      Non-root containers get `root` + a dedicated user (UID/GID 4000)
      with a home directory.

      Returns a list of derivations to include in the image root.
    '';
    file = "nix/modules/oci/lib/mkShadowSetup.nix";
    fn =
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
  };
}
