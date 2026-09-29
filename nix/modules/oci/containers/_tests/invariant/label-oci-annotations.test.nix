# BDD spec for OCI standard annotation coherence (z83.7.20).
#
# Covers spec `Requirement: OCI standard annotation coherence`:
#   org.opencontainers.image.* annotations mirror the package's meta
#   fields (description, licenses, url, authors, documentation, and
#   the always-present base.name).
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      helloMeta = pkgs.hello.meta;
      helloLicense = helloMeta.license.spdxId or "GPL-3.0-or-later";
    in
    {
      test.oci.perContainer.invariant-label-oci-annotations = {
        inspect-description-from-meta = {
          given = "a container built from a package whose meta.description is set";
          "when" = "the OCI image is inspected";
          "then" = "org.opencontainers.image.description equals meta.description";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
          assertions.imageConfig.Labels = {
            "org.opencontainers.image.description" = helloMeta.description;
          };
        };

        inspect-licenses-from-spdx = {
          given = "a container built from a package with meta.license.spdxId";
          "when" = "the OCI image is inspected";
          "then" = "org.opencontainers.image.licenses equals the SPDX ID";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
          assertions.imageConfig.Labels = {
            "org.opencontainers.image.licenses" = helloLicense;
          };
        };

        inspect-url-from-homepage = {
          given = "a container built from a package with meta.homepage";
          "when" = "the OCI image is inspected";
          "then" = "org.opencontainers.image.url equals meta.homepage";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
          assertions.imageConfig.Labels = {
            "org.opencontainers.image.url" = helloMeta.homepage;
          };
        };

        inspect-documentation-from-changelog = {
          given = "a container built from a package with meta.changelog";
          "when" = "the OCI image is inspected";
          "then" = "org.opencontainers.image.documentation equals meta.changelog";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
          assertions.imageConfig.Labels = {
            "org.opencontainers.image.documentation" = helloMeta.changelog;
          };
        };

        inspect-base-name-scratch = {
          given = "a container built without a fromImage base";
          "when" = "the OCI image is inspected";
          "then" = "org.opencontainers.image.base.name = scratch";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
          assertions.imageConfig.Labels = {
            "org.opencontainers.image.base.name" = "scratch";
          };
        };
      };
    };
}
