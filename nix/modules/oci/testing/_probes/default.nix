# Dendritic probe registry.
#
# Each container-probe tool (amicontained, CDK, DEEPCE, linPEAS, ...)
# ships its own sibling file in this directory that appends its name to
# `oci.testing.knownProbes`. The `nix-oci-app-<probe>-<container>`
# systemd oneshot is synthesised by `../test-apps.nix` by iterating that
# merged list and looking up:
#
#   mkAppFn       = config.lib.oci."mkApp${probeNameCapitalized}"
#   enabledPath   = [ "test" probeName "enabled" ]
#
# so the convention is: each probe adds one file here, exports an
# `oci.lib.mkApp<Capitalized>` library function, and declares a per-
# container `oci.container.test.<probe>.enabled` option elsewhere.
# Nothing else needs editing to pick up a new probe.
#
# `_probes/` is `_`-prefixed so `import-tree` does NOT auto-discover
# it from the outer module tree; the siblings get explicitly listed
# below so there is one authoritative place that enumerates them.
# When adding a new probe, update both the sibling file list below
# and `_probes/<name>.nix`.
{
  lib,
  flake-parts-lib,
  ...
}:
{
  imports = [
    ./amicontained.nix
    ./cdk.nix
    ./deepce.nix
    ./linpeas.nix
  ];

  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { ... }:
    {
      options.oci.testing.knownProbes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          List of container-probe names that `test-apps.nix` should
          synthesise `nix-oci-app-<probe>-<container>` apps for.
          Each sibling file in `_probes/` contributes its own name
          via module merge; adding a new probe is a pure addition.
          The order of merge is not meaningful; `test-apps.nix`
          sorts the final list before iterating for deterministic
          output.
        '';
      };
    }
  );
}
