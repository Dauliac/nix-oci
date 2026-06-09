+++
title = "nix-lib functions"
+++

# nix-lib Functions

All library functions share a single implementation in [`nix/lib/oci.nix`](https://github.com/Dauliac/nix-oci/tree/main/nix/lib/oci.nix). They are exposed in two ways:

- **Flake-parts consumers** -- available as `config.lib.oci.*` (per-system) after importing the nix-oci flake-parts module. Module authors declare functions via `nix-lib.lib.oci.*` (the nix-lib framework synthesises them into `config.lib.oci`).
- **NixOS / home-manager deploy modules** -- import `nix/lib/oci.nix` directly.

See also:

- [Source: `nix/lib/oci.nix`](https://github.com/Dauliac/nix-oci/tree/main/nix/lib/oci.nix) -- pure implementations (single source of truth)
- [Source: `nix/modules/oci/lib/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci/lib) -- nix-lib module wrappers (type, description, tests)
- [nix2container](https://github.com/nlewo/nix2container) -- the backend used to build layers and images

---

<!-- OPTIONS:nix-lib -->
