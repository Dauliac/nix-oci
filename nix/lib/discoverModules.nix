# Pure function: recursively discover .nix module files in a directory.
# Excludes _-prefixed subdirectories.
# Used at option-definition time (where config.lib.* is unavailable).
{ lib }:
let
  go =
    dir:
    let
      entries = builtins.readDir dir;
      files = lib.pipe entries [
        (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name))
        builtins.attrNames
        (map (name: dir + "/${name}"))
      ];
      dirs = lib.pipe entries [
        (lib.filterAttrs (name: type: type == "directory" && !lib.hasPrefix "_" name))
        builtins.attrNames
        (lib.concatMap (name: go (dir + "/${name}")))
      ];
    in
    files ++ dirs;
in
go
