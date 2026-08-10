# Import all flake-parts example modules from examples/flake/.
#
# This is a function, not a module. Call it with an exclude list:
#
#   imports = [ (import ./nix/examples.nix { excludes = [ ... ]; }) ];
#
# Or use the default (excludes home-manager, probes, base-images, multi-arch):
#
#   imports = [ (import ./nix/examples.nix { }) ];
{
  excludes ? [
    "/base-images/"
    "/multi-arch/"
    "/with-home-manager-"
    "/minimalist-with-amicontained"
    "/minimalist-with-cdk"
    "/minimalist-with-deepce"
    "/minimalist-with-linpeas"
  ],
}:
# Return a module function
{
  inputs,
  lib,
  ...
}:
let
  exampleTree = inputs.import-tree.filterNot (
    path: lib.any (pattern: lib.hasInfix pattern path) excludes
  );
in
{
  imports = [ (exampleTree ../examples/flake) ];
  # Use default paths: oci.fromImageManifestRootPath = self + "/oci/"
  # Lock files go to ./oci/<containerId>/manifest-lock.json
}
