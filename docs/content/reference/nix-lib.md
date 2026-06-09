+++
title = "nix-lib functions"
+++

# nix-lib Functions

All library functions are exposed under `config.lib.oci.*` (flake-level) or via the `nix-lib.lib.oci.*` module options (per-system). They are automatically available when you import the nix-oci flake-parts module.

See also:

- [Source: `nix/modules/oci/lib/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci/lib)
- [nix2container](https://github.com/nlewo/nix2container) — the backend used to build layers and images

---

<!-- OPTIONS:nix-lib -->
