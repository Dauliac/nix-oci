# file: push.nix
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
          options.push = mkOption {
            type = types.bool
      };
    };
}
# file: push.lib.nix
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      nix-lib.lib.oci.push = {
        # functions here that are useful for push
      };
      test.oci.perContainer.push.container001 = {
        # Here get of the push example code, definition of a list of asserts for this container, blablabla.
        # You can define and use functions from config.nix-lib.lib.tests.oci.perContainer.push namespace
      };
    };
}
# file: push.test.nix
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      nix-lib.lib.test.oci.perContainer.push = {
        # functions here that are useful for push
      };
      test.oci.perContainer.push.container001 = {
        # Here get of the push example code, definition of a list of asserts for this container, blablabla.
        # You can define and use functions from config.nix-lib.lib.tests.oci.perContainer.push namespace
      };
    };
}
