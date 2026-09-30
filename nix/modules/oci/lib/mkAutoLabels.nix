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
              {
                name = "omits nix.deps when dependencies empty";
                check = result: !(result ? "io.github.dauliac.nix-oci.nix.deps");
              }
              {
                name = "omits nix.dependency-count when dependencies empty";
                check = result: !(result ? "io.github.dauliac.nix-oci.nix.dependency-count");
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
          "emits nix.deps when dependencies non-empty" = {
            args = {
              name = "app";
              tag = "1.0";
              package = {
                pname = "app";
                version = "1.0";
                meta.description = "d";
              };
              dependencies = [
                {
                  pname = "libA";
                  version = "1.0";
                  meta.description = "A lib";
                }
                {
                  pname = "libB";
                  version = "2.0";
                  meta.description = "B lib";
                }
              ];
            };
            assertions = [
              {
                name = "nix.deps present";
                check = result: result ? "io.github.dauliac.nix-oci.nix.deps";
              }
              {
                name = "nix.dependency-count reflects list length";
                check = result: result."io.github.dauliac.nix-oci.nix.dependency-count" == "2";
              }
              {
                name = "nix.deps decodes to list of length 2";
                check =
                  result:
                  let
                    parsed = builtins.fromJSON result."io.github.dauliac.nix-oci.nix.deps";
                  in
                  builtins.length parsed == 2;
              }
              {
                name = "first entry preserves pname and description";
                check =
                  result:
                  let
                    first = builtins.head (builtins.fromJSON result."io.github.dauliac.nix-oci.nix.deps");
                  in
                  first.pname == "libA" && first.description == "A lib";
              }
              {
                name = "order matches input list";
                check =
                  result:
                  let
                    parsed = builtins.fromJSON result."io.github.dauliac.nix-oci.nix.deps";
                    names = map (d: d.pname) parsed;
                  in
                  names == [
                    "libA"
                    "libB"
                  ];
              }
            ];
          };
          "omits nix.deps when dependencies empty" = {
            args = {
              name = "app";
              tag = "1.0";
              package = {
                pname = "app";
                version = "1.0";
              };
              dependencies = [ ];
            };
            assertions = [
              {
                name = "no nix.deps key";
                check = result: !(result ? "io.github.dauliac.nix-oci.nix.deps");
              }
            ];
          };
          "nix.deps tolerates missing description" = {
            args = {
              name = "app";
              tag = "1.0";
              package = {
                pname = "app";
                version = "1.0";
              };
              dependencies = [
                {
                  pname = "libA";
                  version = "1.0";
                }
              ];
            };
            assertions = [
              {
                name = "entry still emitted";
                check =
                  result:
                  let
                    parsed = builtins.fromJSON result."io.github.dauliac.nix-oci.nix.deps";
                  in
                  builtins.length parsed == 1
                  && (builtins.head parsed).pname == "libA"
                  && (builtins.head parsed).version == "1.0";
              }
              {
                name = "description key absent when meta.description missing";
                check =
                  result:
                  let
                    first = builtins.head (builtins.fromJSON result."io.github.dauliac.nix-oci.nix.deps");
                  in
                  !(first ? description);
              }
            ];
          };
          "nix.deps caps payload at 4KB" = {
            args = {
              name = "app";
              tag = "1.0";
              package = {
                pname = "app";
                version = "1.0";
              };
              dependencies = builtins.genList (i: {
                pname = "pkg${toString i}";
                version = "1.0";
                meta.description = lib.concatStrings (builtins.genList (_: "x") 100);
              }) 200;
            };
            assertions = [
              {
                name = "label value stays under 4KB";
                check = result: builtins.stringLength result."io.github.dauliac.nix-oci.nix.deps" <= 4096;
              }
              {
                name = "truncation marker present";
                check = result: lib.hasInfix "\"truncated\":true" result."io.github.dauliac.nix-oci.nix.deps";
              }
              {
                name = "dropped counter accounts for missing elements";
                check =
                  result:
                  let
                    parsed = builtins.fromJSON result."io.github.dauliac.nix-oci.nix.deps";
                    marker = lib.last parsed;
                  in
                  (marker.truncated or false) && (marker.dropped or 0) > 0;
              }
            ];
          };
        };
      };
    };
}
