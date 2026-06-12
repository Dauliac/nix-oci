# Pure function: recursively discover .nix module files in a directory.
# Excludes _-prefixed subdirectories.
# Used at option-definition time (where config.lib.* is unavailable).
#
# Accepts either a bare directory path (backward-compatible) or an attrset
# with { dir, filter } where filter is a filename predicate.
{ lib }:
let
  defaultFilter = name: lib.hasSuffix ".nix" name;

  go =
    filter: dir:
    let
      entries = builtins.readDir dir;
      files = lib.pipe entries [
        (lib.filterAttrs (name: type: type == "regular" && filter name))
        builtins.attrNames
        (map (name: dir + "/${name}"))
      ];
      dirs = lib.pipe entries [
        (lib.filterAttrs (name: type: type == "directory" && !lib.hasPrefix "_" name))
        builtins.attrNames
        (lib.concatMap (name: go filter (dir + "/${name}")))
      ];
    in
    files ++ dirs;
in
# Backward-compatible: accepts a path (old API) or { dir, filter } (new API).
arg: if builtins.isAttrs arg then go (arg.filter or defaultFilter) arg.dir else go defaultFilter arg
