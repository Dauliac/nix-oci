+++
title = "Functions Reference"
+++

# Functions Reference

Functions are the **programmatic surface** of nix-oci: helpers exported as
`config.lib.oci.*` (per-system, via the nix-lib framework) that you call from
Nix code to build images, compose layers, derive metadata, generate
hardening artifacts, or wire deploy services. They complement the
[Options Reference](options-index.md): options describe *what* you want,
functions are the tools you reach for when you need to produce something
that the option system doesn't already build for you.

Reach for this section when you are writing Nix code that consumes nix-oci
as a library, or when you need to override a built-in behavior. Every
function on these pages is declared through the nix-lib module system, so
any of them can be replaced from your own flake-parts module (see the
"Overriding functions" section on [flake-parts functions](nix-lib.md)).

## Pages

- [nix-lib: flake-parts functions](nix-lib.md), image builders, layer composition, entrypoint and metadata derivation, labels, security, testing helpers.
- [nix-lib: NixOS deploy functions](nix-lib-nixos-deploy.md), deploy helpers scoped to NixOS.
- [nix-lib: Home Manager deploy functions](nix-lib-home-manager-deploy.md), deploy helpers scoped to Home Manager.
- [nix-lib: system-manager deploy functions](nix-lib-system-manager-deploy.md), deploy helpers scoped to system-manager.

The pure deploy helpers (`copyScript`, `mkPerfOpts`, `allHostPorts`,
`mkRunArgs`, `autoStartContainers`) live once on the [flake-parts functions](nix-lib.md)
page under `oci.deploy.*`; the three deploy-target pages document only the
target-specific wrappers.

## Testing functions

Testing helpers live on a separate page so they only load when the
`nix-oci-test` flake module is imported: see
[nix-lib: testing functions](../test-reference/nix-lib-testing.md).
