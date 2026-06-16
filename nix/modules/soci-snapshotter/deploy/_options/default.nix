# Auto-discover all option files in this directory.
let
  entries = builtins.readDir ./.;
  nixFiles = builtins.filter (
    name:
    name != "default.nix"
    && builtins.substring 0 1 name != "_"
    && builtins.match ".*\\.nix" name != null
  ) (builtins.attrNames entries);
in
map (name: ./. + "/${name}") nixFiles
