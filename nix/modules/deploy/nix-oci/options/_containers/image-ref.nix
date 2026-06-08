# Per-container: computed image reference ("name:tag").
{ config, lib, ... }:
{
  options.imageRef = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    internal = true;
    description = "Computed image reference (name:tag).";
    default = "${config.name}:${config.tag}";
  };
}
