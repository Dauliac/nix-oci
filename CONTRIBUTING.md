+++
title = "Contributing"
+++

# Contributing

Contributions are welcome! Here are some ways to help:

## Getting started

1. Fork and clone the repository
2. Enter the dev shell: `nix develop` (or use [direnv](https://direnv.net/) for automatic activation)
3. The dev shell provides all required tools (bats, lefthook, task, convco, typos, etc.)
4. Git hooks are managed by [lefthook](https://github.com/evilmartians/lefthook) -- they run automatically on commit (formatting, flake check, tests, commit message linting)
5. Make your changes
6. Submit a pull request

## Repository

- Source: [github.com/Dauliac/nix-oci](https://github.com/Dauliac/nix-oci)
- Issues: [github.com/Dauliac/nix-oci/issues](https://github.com/Dauliac/nix-oci/issues)

## Project structure

- `nix/modules/oci/` -- flake-parts build-time modules
- `nix/modules/deploy/` -- NixOS and Home Manager deploy modules
- `nix/modules/_nixos/oci/` -- dendritic NixOS container modules
- `examples/` -- usage examples (build, deploy-nixos, deploy-home-manager)
- `tests/` -- end-to-end and integration tests
- `docs/` -- documentation source (built with [NDG](https://github.com/feel-co/ndg))

## Running tests

```bash
# End-to-end tests (preferred way, via Taskfile)
task test

# All nix checks
nix flake check

# Integration test (NixOS VM)
nix build .#checks.x86_64-linux.deploy-integration
```

## Git hooks (lefthook)

Lefthook runs automatically on commit:

- **pre-commit**: `nix fmt`, `nix flake show`, `nix flake check`, `task test`
- **commit-msg**: [convco](https://convco.github.io/check/) (conventional commits) + typos check

## Code style

- Format with `nix fmt`
- No raw `import` -- use modules or nix-lib
- Prefix internal directories with `_` (excluded from import-tree)

## Related links

- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [flake-parts](https://flake.parts)
- [nix-oci on flake.parts](https://flake.parts/options/nix-oci.html)
- [nix2container](https://github.com/nlewo/nix2container)
