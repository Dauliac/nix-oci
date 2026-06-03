# Container labels option
#
# Exposes OCI Config.Labels as a per-container option.
# Labels are key-value string pairs embedded in the image config,
# inspectable via `docker inspect`, `skopeo inspect --config`, or
# `crane config`.
#
# Keys SHOULD follow reverse domain notation (e.g. org.opencontainers.image.version).
# See: https://specs.opencontainers.org/image-spec/annotations/
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.labels = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              OCI image labels (Config.Labels).

              Key-value string pairs embedded in the image configuration.
              Keys should follow reverse domain notation
              (e.g. `org.opencontainers.image.title`).

              These labels are set at image build time and are immutable
              once the image is produced.
            '';
            example = {
              "org.opencontainers.image.title" = "my-app";
              "org.opencontainers.image.version" = "1.0.0";
            };
          };
        };
    };
}
