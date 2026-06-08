# Per-container: imageRef computed option
{
  name,
  config,
  lib,
  ...
}:
{
  options.imageRef = lib.mkOption {
    type = lib.types.str;
    internal = true;
    readOnly = true;
    description = "Computed image reference (name:tag).";
    default =
      let
        imageName = config.image.imageName or name;
        imageTag = config.image.imageTag or "latest";
      in
      "${imageName}:${imageTag}";
  };
}
