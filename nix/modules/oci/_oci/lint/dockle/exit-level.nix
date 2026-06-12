{ lib, ... }:
{
  options.lint.dockle.exitLevel = lib.mkOption {
    type = lib.types.enum [
      "info"
      "warn"
      "fatal"
    ];
    description = "Minimum severity level that causes a non-zero exit code.";
    default = "info";
  };
}
