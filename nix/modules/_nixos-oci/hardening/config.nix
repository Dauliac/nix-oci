{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container.hardening;

  # -- Service auto-detection --

  hasWebServer = (config.services.nginx.enable or false) || (config.services.httpd.enable or false);

  hasDatabase =
    (config.services.postgresql.enable or false) || ((config.services.redis.servers or { }) != { });

  hasGpu = config.oci.container.gpu.enable or false;

  # Detect bound ports from known services for Landlock defaults.
  detectedTcpBind =
    let
      nginxPorts =
        if config.services.nginx.enable or false then
          let
            defaultPort = config.services.nginx.defaultHTTPListenPort or 80;
          in
          [ defaultPort ]
        else
          [ ];
    in
    nginxPorts;
in
{
  config = lib.mkMerge [
    {
      assertions = lib.optionals cfg.enable [
        {
          assertion = !(cfg.disableDns && cfg.landlock.enable && cfg.landlock.allowedTcpConnect != [ ]);
          message = ''
            nix-oci: `hardening.disableDns = true` but Landlock allows TCP connect to
            ${lib.concatMapStringsSep ", " toString cfg.landlock.allowedTcpConnect}.
            DNS is disabled (nsswitch hosts: files only), so connections to hostnames
            will fail even if Landlock permits the port. Use IP addresses instead.
          '';
        }
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

      # Auto-populate Landlock TCP bind ports from detected services.
      oci.container.hardening.landlock.allowedTcpBind = lib.mkDefault detectedTcpBind;

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
    })
  ];
}
