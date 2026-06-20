# Helper to reduce flake-parts lib module boilerplate.
#
# Every lib.nix file in the codebase repeats:
#   { lib, config, ... }:
#   { config.perSystem = { pkgs, lib, config, ... }:
#     let ociLib = config.lib.oci or { };
#     in { nix-lib.lib.oci = { ... }; };
#   }
#
# This helper captures that structure. Usage:
#
#   import ../../lib/mkLibModule.nix (ctx: {
#     mkScriptFoo = { type = ...; fn = ...; };
#   })
#
# Where `ctx` is: { pkgs, lib, config, ociLib }
#
# For modules that need top-level config access (e.g. flake-level config),
# use the two-argument form:
#
#   import ../../lib/mkLibModule.nix {
#     topLevel = { config, lib, ... }: { cfg = config; };
#     perSystem = topVars: ctx: { ... };
#   }
arg:
if builtins.isFunction arg then
  # Simple form: arg is (ctx -> attrset)
  { ... }:
  {
    config.perSystem =
      {
        pkgs,
        lib,
        config,
        ...
      }:
      {
        # Pass ociLib as a lazy thunk — accessing config.lib.oci during
        # nix-lib.lib.oci definition would create infinite recursion.
        # The thunk is only forced when fn bodies actually call ociLib.*.
        nix-lib.lib.oci = arg {
          inherit pkgs lib config;
          ociLib = config.lib.oci or { };
        };
      };
  }
else
  # Advanced form: arg is { topLevel, perSystem }
  let
    topLevelFn = arg.topLevel or (_: { });
    perSystemFn = arg.perSystem;
  in
  topArgs@{
    lib,
    config,
    ...
  }:
  let
    topVars = topLevelFn topArgs;
  in
  {
    config.perSystem =
      {
        pkgs,
        lib,
        config,
        ...
      }:
      {
        nix-lib.lib.oci = perSystemFn topVars {
          inherit pkgs lib config;
          ociLib = config.lib.oci or { };
        };
      };
  }
