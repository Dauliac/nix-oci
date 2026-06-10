# Forbidden NixOS options: guard against init-dependent features.
#
# nix-oci containers have NO init system (no systemd PID 1, no activation
# scripts, no tmpfiles, no firewall). NixOS options that depend on these
# mechanisms silently do nothing when baked into a container image, leading
# to confusion when expected behavior doesn't appear at runtime.
#
# This module asserts at eval time that none of these footgun options are set.
{
  config,
  lib,
  ...
}:
let
  # system.activationScripts: runs at NixOS boot via switch-to-configuration.
  # Containers never run activation, so these scripts are dead code.
  hasActivationScripts =
    (config.system.activationScripts or { }) != { }
    # NixOS always defines a few internal activation scripts (e.g. "stdio",
    # "var", "usrbinenv"). Only flag user-added ones by checking for non-default
    # keys. The base set is defined by NixOS internals and is safe to ignore.
    && builtins.length (
      builtins.filter (
        name:
        !(lib.elem name [
          "stdio"
          "var"
          "usrbinenv"
          "specialfs"
          "users"
          "groups"
          "etc"
          "nix"
          "wrappers"
          "modprobe"
        ])
      ) (builtins.attrNames (config.system.activationScripts or { }))
    )
    > 0;

  # systemd.tmpfiles.rules / systemd.tmpfiles.settings: requires systemd-tmpfiles
  # which never runs inside a nix-oci container.
  hasTmpfilesRules = (config.systemd.tmpfiles.rules or [ ]) != [ ];
  hasTmpfilesSettings = (config.systemd.tmpfiles.settings or { }) != { };

  # networking.firewall: requires iptables/nftables + kernel modules.
  # Container networking is managed by the runtime (--publish, --network).
  hasFirewall = config.networking.firewall.enable or false;

  # security.pam: requires pam modules + NSS integration.
  # Containers don't authenticate users via PAM.
  hasPamRules =
    let
      pamServices = config.security.pam.services or { };
      # NixOS defines a few PAM services by default (login, su, etc.).
      # Only flag if user added custom rules beyond the defaults.
      customServices = lib.filterAttrs (
        name: _:
        !(lib.elem name [
          "login"
          "su"
          "other"
        ])
      ) pamServices;
    in
    customServices != { } && (builtins.any (svc: (svc.rules or { }) != { }) (builtins.attrValues customServices));

  # security.apparmor / security.audit: kernel-level features.
  hasAppArmor = config.security.apparmor.enable or false;
in
{
  config.assertions = [
    {
      assertion = !hasActivationScripts;
      message = ''
        nix-oci: `system.activationScripts` is set but containers have no init system.
        Activation scripts run during NixOS boot (switch-to-configuration) which
        never happens inside a container image.
        Fix: use Nix derivations to place files (e.g. `pkgs.writeTextDir`), or add
        them to `dependencies` in your container config.
      '';
    }
    {
      assertion = !hasTmpfilesRules;
      message = ''
        nix-oci: `systemd.tmpfiles.rules` is set but containers have no systemd.
        systemd-tmpfiles never runs inside a nix-oci container, so these rules
        will be silently ignored.
        Fix: create the files/directories via Nix derivations and add them to
        `dependencies`, or create them in the container entrypoint script.
      '';
    }
    {
      assertion = !hasTmpfilesSettings;
      message = ''
        nix-oci: `systemd.tmpfiles.settings` is set but containers have no systemd.
        systemd-tmpfiles never runs inside a nix-oci container, so these settings
        will be silently ignored.
        Fix: create the files/directories via Nix derivations and add them to
        `dependencies`, or create them in the container entrypoint script.
      '';
    }
    {
      assertion = !hasFirewall;
      message = ''
        nix-oci: `networking.firewall.enable = true` but containers have no kernel
        access for iptables/nftables. Container networking is managed by the
        runtime (--publish, --network, Kubernetes NetworkPolicy).
        Fix: remove `networking.firewall.enable` and configure port exposure via
        the `ports` option in your container config.
      '';
    }
    {
      assertion = !hasAppArmor;
      message = ''
        nix-oci: `security.apparmor.enable = true` but AppArmor profiles are
        loaded by the host kernel, not the container. Container AppArmor profiles
        are applied by the runtime (--security-opt apparmor=profile).
        Fix: remove `security.apparmor.enable` and configure AppArmor at the
        deploy/runtime level instead.
      '';
    }
  ];
}
