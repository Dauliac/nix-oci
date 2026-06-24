+++
title = "Options: flake-parts"
+++

# Options: flake-parts

Build-time options for defining OCI images in your flake.

See also:

- [flake-parts documentation](https://flake.parts)
- [nix-oci on flake.parts](https://flake.parts/options/nix-oci.html)
- [nix2container](https://github.com/nlewo/nix2container): the backend used to build images
- [nix-oci source: `nix/modules/oci/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci)

## Top-level Options

Set at the flake level (outside `perSystem`).

<!-- OPTIONS:toplevel -->

## Per-System Options

Set inside `perSystem`.

<!-- OPTIONS:persystem -->

## Container Sub-Options

Available on each `oci.containers.<name>`.

<!-- OPTIONS:container -->
