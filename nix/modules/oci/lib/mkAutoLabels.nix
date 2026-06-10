# OCI mkAutoLabels - Generate automatic OCI labels from container config
#
# Produces labels in these categories:
#   1. OCI standard annotations (org.opencontainers.image.*)
#   2. Build info (io.github.dauliac.nix-oci.build.*)
#   3. Hardening hints (io.github.dauliac.nix-oci.hardening.*)
#   4. Kubernetes hints (io.github.dauliac.nix-oci.kubernetes.*)
#      PSS level, SecurityContext fields (runAsUser, seccompProfileType, etc.)
#   5. Network hints (io.github.dauliac.nix-oci.network.*)
#      TCP/UDP ports derived from the ports option
#   6. Nix identity (io.github.dauliac.nix-oci.nix.*)
#      pname, version, mainProgram, dependency count
#   7. Nixpkgs security (io.github.dauliac.nix-oci.security.*)
#      knownVulnerabilities, insecure flag, source provenance
#   8. Runtime info (io.github.dauliac.nix-oci.runtime.*)
#
# All labels are gated behind the `autoLabels` toggle.
# User-provided labels are NOT merged here -- callers do `mkAutoLabels // userLabels`.
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.mkAutoLabels = {
        type = lib.types.functionTo lib.types.attrs;
        description = ''
          Generate automatic OCI labels from container configuration.

          Returns an attrset of label key-value pairs covering:
          - OCI standard annotations (`org.opencontainers.image.*`)
          - Build metadata (`io.github.dauliac.nix-oci.build.*`)
          - Hardening hints (`io.github.dauliac.nix-oci.hardening.*`)
          - Kubernetes hints (`io.github.dauliac.nix-oci.kubernetes.*`)
          - Network hints (`io.github.dauliac.nix-oci.network.*`)
          - Nix identity (`io.github.dauliac.nix-oci.nix.*`)
          - Nixpkgs security (`io.github.dauliac.nix-oci.security.*`)
          - Runtime info (`io.github.dauliac.nix-oci.runtime.*`)

          Callers merge: `mkAutoLabels args // userLabels` (user wins).
        '';
        file = "nix/lib/oci.nix";
        fn = pure.mkAutoLabels;
        tests = {
          "generates OCI annotations" = {
            args = {
              name = "my-app";
              tag = "1.0.0";
              package = {
                pname = "my-app";
                version = "1.0.0";
                name = "my-app-1.0.0";
                meta = {
                  mainProgram = "my-app";
                  description = "Test app";
                  license = {
                    spdxId = "MIT";
                  };
                };
              };
              isRoot = false;
              system = "x86_64-linux";
            };
            assertions = [
              {
                name = "has OCI title";
                check = result: result."org.opencontainers.image.title" == "my-app";
              }
              {
                name = "has OCI version";
                check = result: result."org.opencontainers.image.version" == "1.0.0";
              }
              {
                name = "has nix pname";
                check = result: result."io.github.dauliac.nix-oci.nix.pname" == "my-app";
              }
            ];
          };
          "returns empty when autoLabels disabled" = {
            args = {
              name = "x";
              tag = "latest";
              autoLabels = false;
            };
            expected = { };
          };
        };
      };
    };
}
