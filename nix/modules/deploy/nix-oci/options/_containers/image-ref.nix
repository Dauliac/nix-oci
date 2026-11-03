# Per-container: computed image reference ("name:tag").
#
# The repository (name) part is lowercased: the OCI distribution spec
# requires lowercase repository names and podman rejects mixed-case
# references outright (`repository name must be lowercase`). Container
# names (and thus systemd unit names) keep their original case; only
# derived image references are normalized.
{
  config,
  lib,
  ...
}:
{
  options.imageRef = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    internal = true;
    description = "Computed image reference (lowercased name:tag).";
    default = "${lib.toLower config.name}:${config.tag}";
  };
}
