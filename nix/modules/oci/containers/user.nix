# Container user option (flake-parts wrapper)
#
# The smart default is provided by eval.nix (containerUser), which derives the
# user from service package pname → explicit package pname → container name.
# This module just imports the shared option definition; the fallback default
# (isRoot → "root", else image name) only applies if eval.nix's mkDefault
# is somehow not set.
{ ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        {
          config,
          lib,
          ...
        }:
        {
          imports = [ ./_options/user.nix ];
          # Lowest-priority fallback — eval.nix sets mkDefault with the smart containerUser
          config.user = lib.mkDefault (if config.isRoot then "root" else config.name);
        };
    };
}
