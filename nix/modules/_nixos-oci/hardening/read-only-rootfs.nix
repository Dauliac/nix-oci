# Inner NixOS eval: read-only rootfs flag forwarded from flake-parts.
#
# Runtime hint (deploy modules translate to --read-only) but needed
# by coherence.nix to validate writable-path consistency.
{ lib, ... }:
{
  options.oci.container.hardening.readOnlyRootfs = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Mount container root filesystem as read-only at runtime.";
  };
}
