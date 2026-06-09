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
        file = "nix/modules/oci/lib/mkAutoLabels.nix";
        fn =
          {
            name,
            tag,
            package ? null,
            isRoot ? false,
            optimizeLayers ? false,
            layerStrategy ? "fine-grained",
            hardening ? {
              enable = false;
            },
            ports ? [ ],
            dependencies ? [ ],
            system ? "unknown",
            autoLabels ? true,
          }:
          let
            ns = "io.github.dauliac.nix-oci";

            meta = if package != null then (package.meta or { }) else { };
            pname = if package != null then (package.pname or null) else null;
            version = if package != null then (package.version or null) else null;
            mainProgram = if package != null then (meta.mainProgram or (package.pname or null)) else null;
            description = meta.description or null;
            homepage = meta.homepage or null;
            changelog = meta.changelog or null;
            rawLicense = meta.license or null;
            spdxId =
              if rawLicense == null then
                null
              else if builtins.isList rawLicense then
                let
                  ids = builtins.filter (x: x != null) (map (l: l.spdxId or null) rawLicense);
                in
                if ids == [ ] then null else lib.concatStringsSep " AND " ids
              else
                rawLicense.spdxId or null;
            rawMaintainers = meta.maintainers or [ ];
            maintainerNames = builtins.filter (x: x != null) (
              map (m: m.name or (m.github or null)) rawMaintainers
            );
            authors = if maintainerNames == [ ] then null else lib.concatStringsSep ", " maintainerNames;

            ociAnnotations = {
              "org.opencontainers.image.title" = name;
              "org.opencontainers.image.base.name" = "scratch";
            }
            // lib.optionalAttrs (tag != "latest") { "org.opencontainers.image.version" = tag; }
            // lib.optionalAttrs (version != null && tag == "latest") {
              "org.opencontainers.image.version" = version;
            }
            // lib.optionalAttrs (description != null) {
              "org.opencontainers.image.description" = description;
            }
            // lib.optionalAttrs (spdxId != null) { "org.opencontainers.image.licenses" = spdxId; }
            // lib.optionalAttrs (homepage != null) { "org.opencontainers.image.url" = homepage; }
            // lib.optionalAttrs (authors != null) { "org.opencontainers.image.authors" = authors; }
            // lib.optionalAttrs (changelog != null) {
              "org.opencontainers.image.documentation" = changelog;
            };

            buildInfo = {
              "${ns}.build.system" = system;
              "${ns}.build.optimized-layers" = lib.boolToString optimizeLayers;
              "${ns}.build.layer-strategy" = layerStrategy;
              "${ns}.build.reproducible" = "true";
            };

            hardeningEnabled = hardening.enable or false;
            hardeningLabels = lib.optionalAttrs hardeningEnabled (
              {
                "${ns}.hardening.enabled" = "true";
                "${ns}.hardening.no-new-privileges" = lib.boolToString (hardening.noNewPrivileges or true);
                "${ns}.hardening.read-only-rootfs" = lib.boolToString (hardening.readOnlyRootfs or true);
                "${ns}.hardening.capabilities-drop" = lib.concatStringsSep "," (
                  hardening.capabilities.drop or [ "ALL" ]
                );
              }
              // lib.optionalAttrs ((hardening.capabilities.add or [ ]) != [ ]) {
                "${ns}.hardening.capabilities-add" = lib.concatStringsSep "," hardening.capabilities.add;
              }
              // lib.optionalAttrs (hardening.seccomp.enable or false) {
                "${ns}.hardening.seccomp-profile" = hardening.seccomp.profile or "moderate";
              }
              // lib.optionalAttrs (hardening.landlock.enable or false) {
                "${ns}.hardening.landlock-enabled" = "true";
              }
              // lib.optionalAttrs (hardening.disableDns or false) {
                "${ns}.hardening.dns-disabled" = "true";
              }
              // lib.optionalAttrs (hardening.noTlsTrustStore or false) {
                "${ns}.hardening.tls-trust-store-removed" = "true";
              }
            );

            pssLevel =
              if
                hardeningEnabled
                && !isRoot
                && (hardening.noNewPrivileges or true)
                && builtins.elem "ALL" (hardening.capabilities.drop or [ ])
                && (hardening.seccomp.enable or false)
                && (hardening.readOnlyRootfs or true)
              then
                "restricted"
              else if hardeningEnabled then
                "baseline"
              else
                "privileged";
            pssLabel = lib.optionalAttrs hardeningEnabled {
              "${ns}.kubernetes.pod-security-standard" = pssLevel;
            };

            uid = if isRoot then "0" else "4000";
            gid = if isRoot then "0" else "4000";
            kubernetesSecurityContext = {
              "${ns}.kubernetes.run-as-user" = uid;
              "${ns}.kubernetes.run-as-group" = gid;
              "${ns}.kubernetes.fs-group" = gid;
            }
            // lib.optionalAttrs (hardeningEnabled && (hardening.seccomp.enable or false)) {
              "${ns}.kubernetes.seccomp-profile-type" = "RuntimeDefault";
            };

            parsePort =
              portSpec:
              let
                parts = lib.splitString ":" portSpec;
                raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
                portAndProto = lib.splitString "/" raw;
                port = builtins.head portAndProto;
                proto = if builtins.length portAndProto >= 2 then builtins.elemAt portAndProto 1 else "tcp";
              in
              {
                inherit port proto;
              };
            parsedPorts = map parsePort ports;
            tcpPorts = map (p: p.port) (builtins.filter (p: p.proto == "tcp") parsedPorts);
            udpPorts = map (p: p.port) (builtins.filter (p: p.proto == "udp") parsedPorts);
            networkLabels =
              lib.optionalAttrs (tcpPorts != [ ]) {
                "${ns}.network.tcp-ports" = lib.concatStringsSep "," tcpPorts;
              }
              // lib.optionalAttrs (udpPorts != [ ]) {
                "${ns}.network.udp-ports" = lib.concatStringsSep "," udpPorts;
              };

            nixIdentity =
              lib.optionalAttrs (pname != null) { "${ns}.nix.pname" = pname; }
              // lib.optionalAttrs (version != null) { "${ns}.nix.version" = version; }
              // lib.optionalAttrs (mainProgram != null) { "${ns}.nix.main-program" = mainProgram; }
              // lib.optionalAttrs (dependencies != [ ]) {
                "${ns}.nix.dependency-count" = toString (builtins.length dependencies);
              };

            knownVulns = meta.knownVulnerabilities or [ ];
            rawProvenance = meta.sourceProvenance or [ ];
            provenanceNames = builtins.filter (x: x != null) (
              map (p: p.shortName or (p.name or null)) rawProvenance
            );
            securityLabels =
              lib.optionalAttrs (knownVulns != [ ]) {
                "${ns}.security.known-vulnerabilities" = lib.concatStringsSep "," knownVulns;
                "${ns}.security.insecure" = "true";
              }
              // lib.optionalAttrs (provenanceNames != [ ]) {
                "${ns}.provenance.source-type" = lib.concatStringsSep "," provenanceNames;
              };

            runtimeInfo = {
              "${ns}.runtime.user" = if isRoot then "root" else "non-root";
              "${ns}.runtime.is-root" = lib.boolToString isRoot;
            };
          in
          if autoLabels then
            ociAnnotations
            // buildInfo
            // hardeningLabels
            // pssLabel
            // kubernetesSecurityContext
            // networkLabels
            // nixIdentity
            // securityLabels
            // runtimeInfo
          else
            { };
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
