# Nix store mutual exclusion check: hostStore/hostDaemon vs installNix.
{ lib, helpers }:
ctx:
let
  inherit (ctx) name containerConfig;
in
if helpers.hasNixStoreConflict containerConfig then
  throw ''
    Container "${name}": `nix.hostStore` and `installNix` are mutually exclusive.
    - Use `nix.hostStore = true` to bind-mount the host Nix store (lightweight).
    - Use `installNix = true` to embed a self-contained Nix in the image.
  ''
else
  ""
