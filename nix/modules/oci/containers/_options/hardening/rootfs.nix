# Shared: read-only root filesystem hint.
{
  lib,
  pkgs,
  ...
}:
{
  options.hardening.readOnlyRootfs = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Mount the container root filesystem as read-only at runtime.
      Deploy modules translate to `--read-only`.

      Prevents attackers from writing malware or achieving
      persistence if they gain initial access.
    '';
  };

  config._tests.hardening-rootfs = {
    level = "eval";
    default = {
      package = pkgs.hello;
      hardening.enable = true;
    };
    override = {
      package = pkgs.hello;
      hardening.enable = true;
      hardening.readOnlyRootfs = false;
    };
  };
}
