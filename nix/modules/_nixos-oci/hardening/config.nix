{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container.hardening;

  # -- Service auto-detection --

  hasWebServer = (config.services.nginx.enable or false) || (config.services.httpd.enable or false);

  hasDatabase =
    (config.services.postgresql.enable or false) || ((config.services.redis.servers or { }) != { });

  hasGpu = config.oci.container.gpu.enable or false;
in
{
  config = lib.mkMerge [
    {
      assertions = lib.optionals cfg.enable [
        {
          assertion =
            !(cfg.seccomp.enable && cfg.seccomp.customProfileJson != null && cfg.seccomp.profile != "moderate");
          message = ''
            nix-oci: `hardening.seccomp.customProfileJson` is set but `profile` is also
            explicitly set to "${cfg.seccomp.profile}". The custom JSON takes precedence
            and the `profile` setting is ignored.
            Fix: remove the `profile` setting when using a custom seccomp JSON.
          '';
        }
        {
          assertion =
            !(cfg.seccomp.enable && cfg.seccomp.customProfileJson != null && cfg.seccomp.mode == "audit");
          message = ''
            nix-oci: `hardening.seccomp.customProfileJson` is set but `mode = "audit"`.
            Audit mode only transforms built-in profiles (ERRNO→LOG). Custom profiles
            are used as-is. If you want audit behavior, modify the JSON directly.
            Fix: remove the `mode` setting when using a custom seccomp JSON.
          '';
        }
        {
          assertion = !(cfg.noTlsTrustStore && (config.services.nginx.enable or false));
          message = ''
            nix-oci: `hardening.noTlsTrustStore = true` but nginx is enabled.
            Nginx cannot make upstream HTTPS requests or validate TLS certificates
            without a trust store. Fix: set `hardening.noTlsTrustStore = false`.
          '';
        }
      ];
    }
    (lib.mkIf cfg.enable {
      # Auto-default seccomp profile based on detected services.
      oci.container.hardening.seccomp.profile = lib.mkDefault (
        if hasGpu then
          "gpu-compute"
        else if hasWebServer then
          "web-server"
        else if hasDatabase then
          "database"
        else
          "strict"
      );

      # Override nsswitch to files-only when DNS is disabled.
      environment.etc."nsswitch.conf".text = lib.mkIf cfg.disableDns (
        lib.mkForce ''
          passwd:    files
          group:     files
          shadow:    files
          hosts:     files
          networks:  files
          ethers:    files
          services:  files
          protocols: files
          rpc:       files
        ''
      );

      # -- Unified routing: extraPackages for hardening config files --
      oci.container.extraPackages = lib.optionals cfg.noTlsTrustStore [
        (pkgs.writeTextDir "etc/ssl/certs/ca-bundle.crt" "# TLS trust store removed by nix-oci hardening\n")
      ];

      # -- Unified routing: generatedLabels for hardening hints --
      oci.container.generatedLabels = {
        "io.github.dauliac.nix-oci.hardening.enabled" = "true";
        "io.github.dauliac.nix-oci.hardening.no-new-privileges" =
          if cfg.noNewPrivileges then "true" else "false";
        "io.github.dauliac.nix-oci.hardening.read-only-rootfs" =
          if cfg.readOnlyRootfs then "true" else "false";
      }
      // lib.optionalAttrs (cfg.capabilities.drop != [ ]) {
        "io.github.dauliac.nix-oci.hardening.capabilities-drop" =
          lib.concatStringsSep "," cfg.capabilities.drop;
      }
      // lib.optionalAttrs (cfg.capabilities.add != [ ]) {
        "io.github.dauliac.nix-oci.hardening.capabilities-add" =
          lib.concatStringsSep "," cfg.capabilities.add;
      }
      // lib.optionalAttrs cfg.apparmor.enable {
        "io.github.dauliac.nix-oci.hardening.apparmor-enabled" = "true";
        "io.github.dauliac.nix-oci.hardening.apparmor-mode" = cfg.apparmor.mode;
      };
    })
  ];
}
