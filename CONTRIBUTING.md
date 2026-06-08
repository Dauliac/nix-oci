+++
title = "Contributing"
+++

# Contributing

Contributions are welcome! Here are some ways to help:

## Getting started

1. Fork and clone the repository
2. Enter the dev shell: `nix develop`
3. Make your changes
4. Run tests: `nix flake check`
5. Submit a pull request

## Repository

- Source: [github.com/Dauliac/nix-oci](https://github.com/Dauliac/nix-oci)
- Issues: [github.com/Dauliac/nix-oci/issues](https://github.com/Dauliac/nix-oci/issues)

## Project structure

- `nix/modules/oci/` — flake-parts build-time modules
- `nix/modules/deploy/` — NixOS and Home Manager deploy modules
- `nix/modules/_nixos/oci/` — dendritic NixOS container modules
- `examples/` — usage examples (build, deploy-nixos, deploy-home-manager)
- `tests/` — end-to-end and integration tests
- `docs/` — documentation source (built with [NDG](https://github.com/feel-co/ndg))

## Running tests

```bash
# All checks
nix flake check

# Integration test (NixOS VM)
nix build .#checks.x86_64-linux.deploy-integration

# End-to-end tests
cd tests/end-to-end && bats main.bats
```

## Code style

- Format with `nix fmt`
- No raw `import` — use modules or nix-lib
- Prefix internal directories with `_` (excluded from import-tree)

## Related links

- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [flake-parts](https://flake.parts)
- [nix-oci on flake.parts](https://flake.parts/options/nix-oci.html)
- [nix2container](https://github.com/nlewo/nix2container)
