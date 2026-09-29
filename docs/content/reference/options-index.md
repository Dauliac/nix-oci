+++
title = "Options Reference"
+++

# Options Reference

Options are the **declarative surface** of nix-oci: attribute paths you set
inside a NixOS, Home Manager, system-manager, or flake-parts module to
describe what to build, harden, sign, scan, and deploy. Every option has a
type, a default, and a description; the module system resolves them at
evaluation time.

Reach for this section when you are writing module configuration and need to
answer *"what can I set, and to what value?"*. If instead you are writing
Nix code that calls into nix-oci helpers, see the [Functions Reference](functions-index.md).

## Pages

- [Options: flake-parts](flake-parts-options.md), build-time container definitions under `perSystem.oci.*`.
- [Options: NixOS deploy](nixos-options.md), host-side load and run under `oci.*` in a NixOS module.
- [Options: Home Manager deploy](home-manager-options.md), user-scoped load and run under `oci.*` in a Home Manager module.
- [Options: system-manager deploy](system-manager-options.md), non-NixOS Linux host load and run under `oci.*`.

## When to use which

| Where you write config | Page |
| --- | --- |
| `flake.nix` inside `perSystem` (image build, per-container config) | [flake-parts](flake-parts-options.md) |
| `configuration.nix` on a NixOS host that runs the containers | [NixOS deploy](nixos-options.md) |
| `home.nix` for a rootless user session | [Home Manager deploy](home-manager-options.md) |
| system-manager module on a non-NixOS Linux host | [system-manager deploy](system-manager-options.md) |

The per-container option set (`oci.containers.<name>.*`) is shared across all
four targets, so the descriptions on any of the four pages apply universally.
The differences live in what each target exposes at top level (build-time
outputs vs. runtime services vs. user units).
