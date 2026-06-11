# Inner NixOS eval: no-new-privileges flag forwarded from flake-parts.
#
# Runtime hint (deploy modules translate to --security-opt=no-new-privileges)
# but needed by coherence.nix for cross-backend coherence checks.
{ lib, ... }:
{
  options.oci.container.hardening.noNewPrivileges = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Set the no_new_privs bit to prevent privilege escalation.";
  };
}
