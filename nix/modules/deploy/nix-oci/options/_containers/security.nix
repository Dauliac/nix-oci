# Per-container: computed runtime security options from hardening config.
#
# Translates hardening options into container runtime flags:
#   - seccomp profile → --security-opt seccomp=PATH
#   - noNewPrivileges → --security-opt no-new-privileges
#   - readOnlyRootfs  → --read-only
#   - capabilities    → --cap-drop / --cap-add
#
# These computed options are consumed by run-services.nix (NixOS) and
# run-services.nix (home-manager) to wire into the container runner.
{
  name,
  config,
  lib,
  pkgs,
  ociLib,
  ...
}:
let
  h = config.hardening;
in
{
  options.securityOpts = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    readOnly = true;
    description = "Computed container runtime security flags from hardening config.";
    default = lib.optionals h.enable (
      # Seccomp profile
      lib.optional h.seccomp.enable
        "--security-opt=seccomp=${
          ociLib.mkSeccompProfile {
            inherit name pkgs;
            hardening = h;
          }
        }"
      # No new privileges
      ++ lib.optional h.noNewPrivileges "--security-opt=no-new-privileges"
      # Read-only rootfs
      ++ lib.optional h.readOnlyRootfs "--read-only"
      # Capability drop
      ++ map (c: "--cap-drop=${c}") h.capabilities.drop
      # Capability add
      ++ map (c: "--cap-add=${c}") h.capabilities.add
      # tmpfs for writable /tmp when rootfs is read-only
      ++ lib.optional h.readOnlyRootfs "--tmpfs=/tmp:rw,noexec,nosuid,size=64m"
    );
  };
}
