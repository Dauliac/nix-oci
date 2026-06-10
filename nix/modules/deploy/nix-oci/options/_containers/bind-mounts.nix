# Per-container: NixOS-style bind mounts.
#
# Mirrors the nixpkgs `containers.<name>.bindMounts` option API.
# Each bind mount is converted to a Docker/Podman volume string
# and appended to the `volumes` option automatically.
{
  lib,
  config,
  ...
}:
let
  bindMountOpts =
    { name, ... }:
    {
      options = {
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = name;
          example = "/mnt/data";
          description = "Mount point inside the container.";
        };

        hostPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/home/alice";
          description = ''
            Path on the host to bind into the container.
            Defaults to the same path as `mountPoint` when null.
          '';
        };

        isReadOnly = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether the bind mount is read-only.";
        };
      };

      config = {
        mountPoint = lib.mkDefault name;
      };
    };

  toVolumeString =
    d:
    let
      src = if d.hostPath != null then d.hostPath else d.mountPoint;
      roSuffix = if d.isReadOnly then ":ro" else "";
    in
    "${src}:${d.mountPoint}${roSuffix}";
in
{
  options.bindMounts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule bindMountOpts);
    default = { };
    example = lib.literalExpression ''
      { "/home" = { hostPath = "/home/alice";
                    isReadOnly = false; };
      }
    '';
    description = ''
      Bind mounts from the host into the container.
      Follows the same API as NixOS `containers.<name>.bindMounts`.
      Entries are converted to volume arguments automatically.
    '';
  };

  config.volumes = map toVolumeString (lib.attrValues config.bindMounts);
}
