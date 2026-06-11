# Auto-discover all snapshotter option files recursively.
#
# Traverses subdirectories (soci/, stargz/, zstd-chunked/) and collects
# all .nix files except default.nix. Returns a flat list of paths
# suitable for use as NixOS module imports.
let
  discoverDir =
    dir:
    let
      entries = builtins.readDir dir;
      names = builtins.attrNames entries;
      nixFiles = builtins.filter (
        name: name != "default.nix" && builtins.match ".*\\.nix" name != null
      ) names;
      subDirs = builtins.filter (
        name: entries.${name} == "directory" && builtins.substring 0 1 name != "_"
      ) names;
    in
    map (name: dir + "/${name}") nixFiles
    ++ builtins.concatMap (name: discoverDir (dir + "/${name}")) subDirs;
in
discoverDir ./.
