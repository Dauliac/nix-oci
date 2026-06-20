# Mount shared container options under oci.container.* namespace.
#
# The _options/ files are the single source of truth for option declarations.
# This module imports each one and re-namespaces it from root-level
# (options.X) to NixOS-eval-level (options.oci.container.X).
#
# Only Tier 1 options (container content, forwarded to NixOS eval) are
# listed here. Tier 2 (image artifact: name, tag, compression, turbo)
# and Tier 3 (CI/quality) are NOT mounted in the NixOS eval.
#
# IMPORTANT: Use path literals (not string interpolation) so that
# relative paths inside option files (e.g. readFile ../examples/...)
# resolve correctly in pure eval mode.
#
# When adding a new shared option to _options/, add one line here.
{ lib, ... }:
let
  optionsDir = ../oci/containers/_options;

  # Tier 1 option files: container content forwarded to NixOS eval.
  # Listed explicitly to avoid pulling in Tier 2 build-time-only options.
  # Path literals preserve correct relative path resolution.
  tier1Files = [
    # Core identity
    (optionsDir + "/package.nix")
    (optionsDir + "/dependencies.nix")
    (optionsDir + "/user.nix")
    (optionsDir + "/is-root.nix")
    (optionsDir + "/uid.nix")
    (optionsDir + "/gid.nix")
    (optionsDir + "/main-service.nix")
    # initializeNixDatabase is Tier 2 (build-time only, not forwarded to NixOS eval)
    # installNix stays in _nixos-oci/nix-support/options.nix (NixOS-only)

    # Runtime behavior
    (optionsDir + "/entrypoint.nix")
    (optionsDir + "/stop-signal.nix")
    (optionsDir + "/working-dir.nix")
    (optionsDir + "/declared-volumes.nix")
    (optionsDir + "/environment.nix")

    # Health
    (optionsDir + "/healthcheck.nix")

    # Home-manager
    (optionsDir + "/home-manager.nix")

    # Hardening (all except landlock which stays NixOS-only)
    (optionsDir + "/hardening/enable.nix")
    (optionsDir + "/hardening/dns.nix")
    (optionsDir + "/hardening/tls.nix")
    (optionsDir + "/hardening/seccomp.nix")
    # landlock stays in _nixos-oci/hardening/landlock.nix (NixOS-only, no _options/ counterpart)
    (optionsDir + "/hardening/apparmor.nix")
    (optionsDir + "/hardening/capabilities.nix")
    (optionsDir + "/hardening/rootfs.nix")
    (optionsDir + "/hardening/privileges.nix")

    # Performance (Tier 1 only — NOT compression, march, hwcaps, turbo)
    (optionsDir + "/performance/enable.nix")
    (optionsDir + "/performance/allocator.nix")
    (optionsDir + "/performance/allocator-config.nix")
    (optionsDir + "/performance/compiler.nix")
    (optionsDir + "/performance/glibc-tunables.nix")
    (optionsDir + "/performance/glibc-tunables-preset.nix")
    (optionsDir + "/performance/huge-pages.nix")
    (optionsDir + "/performance/startup.nix")

    # GPU (all)
    (optionsDir + "/gpu/enable.nix")
    (optionsDir + "/gpu/capabilities.nix")
    (optionsDir + "/gpu/cuda-version.nix")
    (optionsDir + "/gpu/forward-compat.nix")
    (optionsDir + "/gpu/runtime-libraries.nix")
  ];

  # Wrap an _options/ module: re-namespace from options.X → options.oci.container.X
  # Uses _module.args to access pkgs and other module args that the inner module may need.
  wrapModule =
    path:
    args@{
      lib,
      config,
      options,
      pkgs,
      ...
    }:
    let
      # Call the _options/ module with full module args
      mod = import path args;
    in
    {
      options.oci.container = mod.options or { };
    };
in
{
  imports = map wrapModule tier1Files;
}
