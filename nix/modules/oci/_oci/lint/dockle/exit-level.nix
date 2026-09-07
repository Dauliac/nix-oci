{ lib, ... }:
{
  options.lint.dockle.exitLevel = lib.mkOption {
    type = lib.types.enum [
      "info"
      "warn"
      "fatal"
    ];
    description = ''
      Minimum severity level that causes a non-zero exit code.

      Defaults to `fatal` so `nix flake check` does not fail on WARN or
      INFO findings — nix-oci deliberately surfaces choices like
      `isRoot = true` and per-container `test.dockle.enabled = false`
      instead of silently rewriting the image. Projects that want a
      stricter gate can set this to `warn` or `info` per-container.
    '';
    default = "fatal";
  };
}
