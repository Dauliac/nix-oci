# NixOS config integration - assertions and mainService -> package derivation
#
# This module handles:
# - Mutual exclusion assertion (package vs mainService)
# - Type="forking" warning
# - Port/privilege coherence (non-root + privileged port, dropped caps)
# - Seccomp profile vs service requirements (networking, threading)
# - Landlock policy vs detected ports and healthcheck
# - Hardening vs healthcheck coherence (TLS, DNS)
# - Read-only rootfs vs writable directories
# - Auto-deriving package from mainService (so name/tag auto-derive too)
#
# Everything else (entrypoint, shadow, env, configFiles, dependencies) is now
# managed by the NixOS module (nix/nixos/oci-container.nix) via the eval.
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        {
          config,
          name,
          ...
        }:
        let
          nixosCfg = config.nixosConfig;
          enabled = nixosCfg.enable;
          eval = nixosCfg.eval;
          mainService = nixosCfg.mainService or null;
          out = eval.oci.container._output;

          servicePackage = out.servicePackage or null;
          serviceType =
            if out.serviceData or null != null then out.serviceData.serviceType or "simple" else "simple";

          # -- Port/privilege coherence helpers --

          # Parse container port from a mapping string (e.g. "8080:80" → 80)
          parsePortInt =
            portSpec:
            let
              parts = lib.splitString ":" portSpec;
              raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
              clean = builtins.head (lib.splitString "/" raw);
            in
            lib.toInt clean;

          explicitPorts = map parsePortInt (config.ports or [ ]);
          detectedPorts = out.detectedPorts or [ ];
          allPorts = lib.unique (explicitPorts ++ detectedPorts);
          privilegedPorts = builtins.filter (p: p > 0 && p < 1024) allPorts;
          hasPrivilegedPorts = privilegedPorts != [ ];
          hasPorts = allPorts != [ ];

          h = config.hardening;
          capsAdd = h.capabilities.add or [ ];
          capsDrop = h.capabilities.drop or [ ];
          hasNetBindService = lib.elem "NET_BIND_SERVICE" capsAdd;
          dropsAll = lib.elem "ALL" capsDrop;

          # -- Seccomp helpers --
          seccompEnabled = h.enable && h.seccomp.enable;
          seccompProfile = h.seccomp.profile or "moderate";
          isStrictSeccomp = seccompEnabled && seccompProfile == "strict";
          # Services that fork worker processes (need clone/clone3/wait4/tgkill)
          forkingServices = [
            "nginx"
            "httpd"
            "postgresql"
            "named"
            "postfix"
          ];
          serviceNeedsForking = mainService != null && lib.elem mainService forkingServices;

          # -- Landlock helpers --
          landlockEnabled = h.enable && h.landlock.enable;
          landlockTcpBind = h.landlock.allowedTcpBind or [ ];
          landlockTcpConnect = h.landlock.allowedTcpConnect or [ ];
          missingBindPorts = builtins.filter (p: !(lib.elem p landlockTcpBind)) detectedPorts;

          # -- Healthcheck helpers --
          healthcheck = out.healthcheck or null;
          healthCmd = if healthcheck != null then healthcheck.command or [ ] else [ ];
          healthCmdStr = lib.concatStringsSep " " healthCmd;
          healthcheckHasHttps = lib.any (arg: lib.hasInfix "https://" arg) healthCmd;
          healthcheckHasInsecureFlag = lib.any (arg: arg == "-k" || arg == "--insecure") healthCmd;
          # Extract port from healthcheck URL (http://localhost:PORT/...)
          healthcheckPort =
            let
              urlArgs = builtins.filter (
                arg: lib.hasInfix "://localhost" arg || lib.hasInfix "://127.0.0.1" arg
              ) healthCmd;
              url = if urlArgs != [ ] then builtins.head urlArgs else "";
              # Extract port after "localhost:" or "127.0.0.1:"
              afterHost =
                let
                  parts = lib.splitString ":" url;
                in
                if builtins.length parts >= 3 then builtins.elemAt parts 2 else "";
              portStr = builtins.head (lib.splitString "/" afterHost);
            in
            if portStr != "" then
              let
                parsed = builtins.tryEval (lib.toInt portStr);
              in
              if parsed.success then parsed.value else null
            else
              null;
          missingHealthcheckConnect =
            landlockEnabled
            && healthcheckPort != null
            && !(lib.elem healthcheckPort landlockTcpConnect)
            # The healthcheck port is also not in the bind list (bind implies connect to same port)
            && !(lib.elem healthcheckPort landlockTcpBind);

          # -- DNS + healthcheck hostname detection --
          # Check if healthcheck references a hostname (not IP, not localhost)
          healthcheckUsesHostname =
            let
              urlArgs = builtins.filter (arg: lib.hasInfix "://" arg) healthCmd;
            in
            urlArgs != [ ]
            && !(lib.any (
              arg:
              lib.hasInfix "://localhost" arg || lib.hasInfix "://127.0.0.1" arg || lib.hasInfix "://[::1]" arg
            ) urlArgs);

          # -- Read-only rootfs + writable dirs --
          serviceData = out.serviceData or null;
          writableDirs =
            if serviceData != null then
              (map (d: "/run/${d}") (serviceData.runtimeDirs or [ ]))
              ++ (map (d: "/var/lib/${d}") (serviceData.stateDirs or [ ]))
              ++ (map (d: "/var/cache/${d}") (serviceData.cacheDirs or [ ]))
              ++ (map (d: "/var/log/${d}") (serviceData.logDirs or [ ]))
            else
              [ ];
          declaredVolumes = out.declaredVolumes or [ ];
          # Dirs the service writes to but that aren't covered by declared volumes
          uncoveredWriteDirs = builtins.filter (d: !(lib.elem d declaredVolumes) && d != "/tmp") writableDirs;
        in
        {
          options.nixosConfig._checks = lib.mkOption {
            type = lib.types.str;
            internal = true;
            readOnly = true;
            description = "Internal: force-evaluated during build to check assertions.";
            default =
              let
                packageConflict =
                  enabled
                  && mainService != null
                  && config.package != null
                  && servicePackage != null
                  && config.package != servicePackage;
                isForkingService = enabled && mainService != null && serviceType == "forking";

                # -- Port/privilege violations --

                # Non-root container trying to bind a privileged port without
                # the NET_BIND_SERVICE capability.
                privilegedPortViolation =
                  enabled && h.enable && !config.isRoot && hasPrivilegedPorts && !hasNetBindService;

                # Root container that drops ALL capabilities (including
                # NET_BIND_SERVICE) but still needs a privileged port.
                rootDroppedBindViolation =
                  enabled && h.enable && config.isRoot && hasPrivilegedPorts && dropsAll && !hasNetBindService;

                portList = lib.concatMapStringsSep ", " toString privilegedPorts;

                # -- Seccomp violations --

                # Strict seccomp blocks socket/bind/listen/connect — service
                # with detected ports will crash with EPERM.
                seccompBlocksNetworking = enabled && isStrictSeccomp && hasPorts;

                # Strict seccomp blocks clone/clone3/wait4 — multi-process
                # services (nginx workers, postgresql backends) will fail.
                seccompBlocksForking = enabled && isStrictSeccomp && serviceNeedsForking;

                # -- Landlock violations --

                # Landlock allowedTcpBind doesn't include all detected ports.
                landlockMissingBindPorts = enabled && landlockEnabled && missingBindPorts != [ ];

                missingBindList = lib.concatMapStringsSep ", " toString missingBindPorts;

                # Landlock allowedTcpConnect doesn't include healthcheck port.
                landlockBlocksHealthcheck = enabled && missingHealthcheckConnect;

                # -- Hardening vs healthcheck --

                # TLS trust store removed but healthcheck uses HTTPS without -k.
                tlsBlocksHealthcheck =
                  enabled && (h.noTlsTrustStore or false) && healthcheckHasHttps && !healthcheckHasInsecureFlag;

                # DNS disabled but healthcheck references a hostname (not IP).
                dnsBlocksHealthcheck = enabled && (h.disableDns or false) && healthcheckUsesHostname;

                # -- Read-only rootfs --

                # Service needs writable dirs not in declared volumes.
                rootfsBlocksWrites = enabled && (h.readOnlyRootfs or false) && uncoveredWriteDirs != [ ];

                uncoveredDirList = lib.concatMapStringsSep ", " (d: "\"${d}\"") uncoveredWriteDirs;
              in
              # -- Package conflict (error) --
              (
                if packageConflict then
                  throw ''
                    Container "${name}": cannot set both `package` and `nixosConfig.mainService`.
                    - To let the NixOS service provide the package: remove `package`, set `mainService`.
                    - To control the package yourself: remove `mainService`, set `package` explicitly.
                  ''
                else
                  ""
              )
              # -- Forking service type (warning) --
              + (
                if isForkingService then
                  builtins.trace ''
                    WARNING: Container "${name}": service "${mainService}" uses Type="forking".
                    The process will daemonize and the container may exit immediately.
                  '' ""
                else
                  ""
              )
              # -- Privileged port + non-root (error) --
              + (
                if privilegedPortViolation then
                  throw ''
                    Container "${name}": non-root user cannot bind privileged port(s): ${portList}.
                    Fix with one of:
                      - Set `isRoot = true`
                      - Use a port >= 1024 (e.g. services.nginx.defaultHTTPListenPort = 8080)
                      - Add `hardening.capabilities.add = [ "NET_BIND_SERVICE" ]`
                  ''
                else
                  ""
              )
              # -- Privileged port + dropped caps (error) --
              + (
                if rootDroppedBindViolation then
                  throw ''
                    Container "${name}": capabilities drop ALL but port(s) ${portList} require NET_BIND_SERVICE.
                    Fix with one of:
                      - Add `hardening.capabilities.add = [ "NET_BIND_SERVICE" ]`
                      - Use a port >= 1024 (e.g. services.nginx.defaultHTTPListenPort = 8080)
                  ''
                else
                  ""
              )
              # -- Seccomp strict + networking (error) --
              + (
                if seccompBlocksNetworking then
                  throw ''
                    Container "${name}": seccomp profile "strict" blocks networking syscalls
                    (socket, bind, listen, connect) but the service binds port(s): ${
                      lib.concatMapStringsSep ", " toString allPorts
                    }.
                    Fix with one of:
                      - Use `hardening.seccomp.profile = "web-server"` (adds networking + threading)
                      - Use `hardening.seccomp.profile = "moderate"` (blocklist instead of allowlist)
                  ''
                else
                  ""
              )
              # -- Seccomp strict + forking service (error) --
              + (
                if seccompBlocksForking then
                  throw ''
                    Container "${name}": seccomp profile "strict" blocks process syscalls
                    (clone, clone3, wait4) but "${mainService}" forks worker processes.
                    Fix with one of:
                      - Use `hardening.seccomp.profile = "web-server"` (adds threading syscalls)
                      - Use `hardening.seccomp.profile = "moderate"` (blocklist instead of allowlist)
                  ''
                else
                  ""
              )
              # -- Landlock missing bind ports (error) --
              + (
                if landlockMissingBindPorts then
                  throw ''
                    Container "${name}": Landlock restricts TCP bind but port(s) ${missingBindList}
                    detected from "${mainService}" are not in `hardening.landlock.allowedTcpBind`.
                    Fix: add the missing port(s):
                      hardening.landlock.allowedTcpBind = [ ${missingBindList} ];
                  ''
                else
                  ""
              )
              # -- Landlock blocks healthcheck connect (warning) --
              + (
                if landlockBlocksHealthcheck then
                  builtins.trace ''
                    WARNING: Container "${name}": Landlock restricts TCP connect but the healthcheck
                    targets port ${toString healthcheckPort} which is not in `hardening.landlock.allowedTcpConnect`.
                    The healthcheck will fail at runtime. Fix:
                      hardening.landlock.allowedTcpConnect = [ ${toString healthcheckPort} ];
                  '' ""
                else
                  ""
              )
              # -- TLS trust store removed + HTTPS healthcheck (error) --
              + (
                if tlsBlocksHealthcheck then
                  throw ''
                    Container "${name}": `hardening.noTlsTrustStore = true` removes TLS certificates
                    but the healthcheck uses HTTPS: ${healthCmdStr}
                    Fix with one of:
                      - Set `hardening.noTlsTrustStore = false`
                      - Switch healthcheck to HTTP
                      - Add `-k` to the healthcheck command to skip certificate validation
                  ''
                else
                  ""
              )
              # -- DNS disabled + healthcheck uses hostname (warning) --
              + (
                if dnsBlocksHealthcheck then
                  builtins.trace ''
                    WARNING: Container "${name}": `hardening.disableDns = true` but the healthcheck
                    references a hostname: ${healthCmdStr}
                    DNS resolution will fail. Use an IP address (127.0.0.1) instead.
                  '' ""
                else
                  ""
              )
              # -- Read-only rootfs + uncovered writable dirs (warning) --
              + (
                if rootfsBlocksWrites then
                  builtins.trace ''
                    WARNING: Container "${name}": `hardening.readOnlyRootfs = true` but the service
                    writes to directories not covered by declared volumes: ${uncoveredDirList}.
                    These writes will fail at runtime. Fix with one of:
                      - Add them to `declaredVolumes`
                      - Mount them as tmpfs via deploy config
                  '' ""
                else
                  ""
              );
          };

          config = lib.mkIf (enabled && mainService != null && servicePackage != null) {
            # Auto-derive package from mainService so name/tag cascade
            package = lib.mkDefault servicePackage;
          };
        };
    };
}
