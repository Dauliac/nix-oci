# Per-container: OCI WorkingDir configuration.
#
# Sets the working directory for the container process. For NixOS
# containers, auto-derived from systemd WorkingDirectory, then
# service dataDir, then user home directory.
{ lib, ... }:
{
  options.workingDir = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Working directory for the container process.
      When null, auto-derived for NixOS containers from:
      1. systemd WorkingDirectory
      2. service dataDir (e.g., /var/lib/postgresql for PostgreSQL)
      3. user home directory (/root or /home/<user>)

      For non-NixOS containers, defaults to the user home directory.
    '';
    example = "/var/lib/postgresql";
  };
}
