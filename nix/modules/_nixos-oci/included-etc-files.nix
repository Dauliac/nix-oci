# /etc file inclusion for container images.
#
# By default, ALL files from NixOS environment.etc are included in the
# container image, EXCEPT known-useless NixOS defaults (os-release,
# machine-id, systemd configs, etc.).
#
# Users and modules can add to the denylist via excludedEtcFiles.
{ lib, ... }:
{
  options.oci.container.excludedEtcFiles = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    # Leave the option's default empty so contributions from every module
    # (including this file's own config below) concatenate. A non-empty
    # `default = [ ... ]` here is silently dropped as soon as any other
    # module sets the option — that is what nixos-25.11's `listOf` merge
    # does, and it caused the hardening module's `[ "ssl" ]` addition to
    # blow away every other exclusion.
    default = [ ];
    description = ''
      Names of /etc entries to EXCLUDE from the container image.

      All other files from NixOS `environment.etc` are included.
      Prefix matching: "systemd" excludes "systemd/system", "systemd/user", etc.
    '';
  };

  config.oci.container.excludedEtcFiles = [
    # NixOS identity — useless/wrong in containers
    "os-release"
    "machine-id"
    "hostname"
    # systemd — no systemd PID 1 in containers
    "systemd"
    "tmpfiles.d"
    "udev"
    # Runtime bind-mounted by container runtimes
    "resolv.conf"
    "hosts"
    # Login/PAM — no login sessions in containers
    "pam.d"
    "login.defs"
    "security"
    "securetty"
    # Fonts — no GUI in containers
    "fonts"
    # Shells/profile — containers use explicit entrypoints
    "shells"
    "profile"
    "bashrc"
    "inputrc"
    "skel"
    # NixOS-specific — not useful in containers
    "nixos"
    "nix/registry.json"
    "static"
    "set-environment"
  ];
}
