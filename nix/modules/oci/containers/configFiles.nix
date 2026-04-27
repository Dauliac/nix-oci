# Container configFiles option
#
# Allows emplacing arbitrary config files in the container image.
# Each entry is a derivation containing a directory tree that gets
# merged into the container root (e.g., writeTextDir "etc/foo/bar" "...").
#
# Unlike `dependencies` (which adds packages to /bin), configFiles
# is intended for config files under /etc, /var, or any path that
# isn't a package with binaries.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.configFiles = mkOption {
            type = types.listOf types.package;
            description = ''
              Config file derivations to emplace in the container image.

              Each entry should be a derivation producing a directory tree
              rooted at $out (e.g., pkgs.writeTextDir "etc/foo.conf" "...").
              These are merged into the container root filesystem.
            '';
            default = [ ];
            example = lib.literalExpression ''
              [
                (pkgs.writeTextDir "etc/containers/policy.json"
                  (builtins.toJSON { default = [{ type = "insecureAcceptAnything"; }]; }))
              ]
            '';
          };
        };
    };
}
