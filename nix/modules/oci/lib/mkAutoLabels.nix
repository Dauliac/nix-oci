# OCI mkAutoLabels - Generate automatic OCI labels from container config
#
# Produces three categories of labels:
#   1. OCI standard annotations (org.opencontainers.image.*)
#      Derived from package metadata (pname, version, description, license, etc.)
#   2. Build info (io.github.dauliac.nix-oci.build.*)
#      System, layer strategy, reproducibility flag
#   3. Hardening hints (io.github.dauliac.nix-oci.hardening.*)
#      Security posture + Kubernetes Pod Security Standard level
#
# All labels are gated behind the `autoLabels` toggle.
# User-provided labels are NOT merged here — callers do `mkAutoLabels // userLabels`.
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
          - Kubernetes PSS level (`io.github.dauliac.nix-oci.kubernetes.pod-security-standard`)

          Callers merge: `mkAutoLabels args // userLabels` (user wins).
        '';
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
            system ? "unknown",
            autoLabels ? true,
          }:
          let
            ns = "io.github.dauliac.nix-oci";

            # -- Helpers to safely extract package metadata --
            meta = if package != null then (package.meta or { }) else { };
            pname = package.pname or (package.name or null);
            version = package.version or null;
            description = meta.description or null;
            homepage = meta.homepage or null;
            changelog = meta.changelog or null;

            # License: handle single license or list of licenses
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

            # Maintainers: extract name or github handle
            rawMaintainers = meta.maintainers or [ ];
            maintainerNames = builtins.filter (x: x != null) (
              map (m: m.name or (m.github or null)) rawMaintainers
            );
            authors = if maintainerNames == [ ] then null else lib.concatStringsSep ", " maintainerNames;

            # -- OCI standard annotations --
            ociAnnotations = {
              "org.opencontainers.image.title" = name;
            }
            // lib.optionalAttrs (tag != "latest") {
              "org.opencontainers.image.version" = tag;
            }
            // lib.optionalAttrs (version != null && tag == "latest") {
              "org.opencontainers.image.version" = version;
            }
            // lib.optionalAttrs (description != null) {
              "org.opencontainers.image.description" = description;
            }
            // lib.optionalAttrs (spdxId != null) {
              "org.opencontainers.image.licenses" = spdxId;
            }
            // lib.optionalAttrs (homepage != null) {
              "org.opencontainers.image.url" = homepage;
            }
            // lib.optionalAttrs (authors != null) {
              "org.opencontainers.image.authors" = authors;
            }
            // lib.optionalAttrs (changelog != null) {
              "org.opencontainers.image.documentation" = changelog;
            }
            // {
              # Always "scratch" — nix-oci is distroless by construction
              "org.opencontainers.image.base.name" = "scratch";
            };

            # -- Build info --
            buildInfo = {
              "${ns}.build.system" = system;
              "${ns}.build.optimized-layers" = lib.boolToString optimizeLayers;
              "${ns}.build.layer-strategy" = layerStrategy;
              "${ns}.build.reproducible" = "true";
            };

            # -- Hardening labels --
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

            # -- Kubernetes Pod Security Standard level --
            #
            # Restricted: non-root + drop ALL + no new privs + seccomp + read-only rootfs
            # Baseline:   hardening enabled with some restrictions
            # Privileged: no hardening or running as root without restrictions
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

            # -- Runtime info --
            runtimeInfo = {
              "${ns}.runtime.user" = if isRoot then "root" else "non-root";
              "${ns}.runtime.is-root" = lib.boolToString isRoot;
            };
          in
          if autoLabels then
            ociAnnotations // buildInfo // hardeningLabels // pssLabel // runtimeInfo
          else
            { };
      };
    };
}
