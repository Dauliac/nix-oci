# Auto-discover all performance submodule files in this directory.
let
  dir = builtins.readDir ./.;
  nixFiles = builtins.filter (name: name != "default.nix" && builtins.match ".*\\.nix" name != null) (
    builtins.attrNames dir
  );
in
map (name: ./. + "/${name}") nixFiles
