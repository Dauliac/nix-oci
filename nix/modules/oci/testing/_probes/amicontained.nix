# Probe registration: amicontained (jessfraz container-runtime fingerprinter).
#
# `test-apps.nix` picks this up by iterating `oci.testing.knownProbes`
# and emits `nix-oci-app-amicontained-<container>.service` for every
# container whose `test.amicontained.enabled = true`.
{ ... }:
{
  perSystem.oci.testing.knownProbes = [ "amicontained" ];
}
