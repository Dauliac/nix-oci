# Runtime-overridden paths: guard against useless image config.
#
# Container runtimes (Docker, Podman, containerd, CRI-O) always bind-mount
# certain /etc files at startup, masking anything baked into the image layer.
# Writing these files into the image is a no-op at best, misleading at worst.
#
# Overridden paths:
#   /etc/resolv.conf  -- DNS resolver (--dns, --dns-search, --dns-opt)
#   /etc/hostname     -- container hostname (--hostname)
#   /etc/hosts        -- host entries (--add-host, container ID)
#
# NOT overridden (safe to bake):
#   /etc/nsswitch.conf, /etc/passwd, /etc/group, /etc/shadow,
#   /etc/ssl/certs/*, /etc/nix/nix.conf, etc.
{
  config,
  lib,
  ...
}:
let
  runtimeOverriddenEtcNames = [
    "resolv.conf"
    "hostname"
    "hosts"
  ];

  # Fail the build when user's NixOS modules write to runtime-overridden etc paths.
  # Guard: environment.etc may not exist in minimal NixOS evals (e.g. mkCrossOCI).
  hasEnvironmentEtc = config ? environment && config.environment ? etc;
  etcAssertions =
    if !hasEnvironmentEtc then
      [ ]
    else
      let
        etc = config.environment.etc;
      in
      map (name: {
        assertion = !(etc ? ${name});
        message = ''
          nix-oci: /etc/${name} is always bind-mounted by the container runtime
          at startup. Writing it into the image via `environment.etc."${name}"`
          has no effect. Remove this setting, or enforce the policy at runtime
          (e.g. --dns, --hostname, --add-host).
        '';
      }) runtimeOverriddenEtcNames;
in
{
  options.oci.container.runtimeOverriddenEtcNames = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    readOnly = true;
    internal = true;
    default = runtimeOverriddenEtcNames;
    description = ''
      List of /etc file names that container runtimes always bind-mount,
      masking any content baked into the image layer.
    '';
  };

  config.assertions = etcAssertions;
}
