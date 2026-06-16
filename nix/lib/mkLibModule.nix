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
      let
        ociLib = config.lib.oci or { };
        entries = arg {
          inherit
            pkgs
            lib
            config
            ociLib
            ;
        };
      in
      {
        nix-lib.lib.oci = entries;
      };
  }
else
  # Advanced form: arg is { topLevel, perSystem }
  let
    topLevelFn = arg.topLevel or (_: { });
    perSystemFn = arg.perSystem;
  in
  topArgs@{ lib, config, ... }:
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
      let
        ociLib = config.lib.oci or { };
        entries = perSystemFn topVars {
          inherit
            pkgs
            lib
            config
            ociLib
            ;
        };
      in
      {
        nix-lib.lib.oci = entries;
      };
  }
