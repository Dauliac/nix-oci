# Per-container: run mode (daemon or oneshot).
{ lib, ... }:
{
  options.mode = lib.mkOption {
    type = lib.types.enum [
      "daemon"
      "oneshot"
    ];
    default = "daemon";
    description = ''
      Container run mode:

      - `"daemon"` — long-running service, restarted on failure.
        Used for web servers, databases, etc.
      - `"oneshot"` — runs once and exits. Systemd records the exit code.
        Used for init tasks, migrations, test assertions.
    '';
  };
}
