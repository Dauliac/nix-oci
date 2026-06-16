# Shared: no-new-privileges flag.
{
  lib,
  ...
}:
{
  options.hardening.noNewPrivileges = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Set the `no_new_privs` bit. Prevents privilege escalation
      via setuid/setgid binaries or file capabilities.

      Deploy modules translate to
      `--security-opt=no-new-privileges`.
    '';
  };
}
