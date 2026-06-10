# Shared container integration checks.
#
# Pure function library that validates container configuration coherence.
# Called from both flake-parts integration.nix and deploy nixos-integration.nix.
#
# Top-level helpers are reusable and wrapped by nix-lib (nix/modules/oci/lib/checks.nix).
# `runChecks` orchestrates all checks and returns ""/throws/traces.
{ lib }:
let
  ociLib = import ./oci.nix { inherit lib; };

  self = {
    # -- Reusable helpers (exposed via nix-lib as config.lib.oci.checks.*) --

    # Detect nix.hostStore / installNix mutual exclusion conflict.
    hasNixStoreConflict =
      containerConfig:
      let
        nixHostStore = (containerConfig.nix or { }).hostStore or false;
        nixHostDaemon = (containerConfig.nix or { }).hostDaemon or false;
        installNixEnabled = containerConfig.installNix or false;
      in
      (nixHostStore || nixHostDaemon) && installNixEnabled;

    # Extract the container port as integer from a port mapping spec.
    # Delegates to oci.nix parseContainerPortInt.
    parsePortInt = ociLib.parseContainerPortInt;

    # Filter ports below 1024 (privileged) from a list of integers.
    extractPrivilegedPorts = ports: builtins.filter (p: p > 0 && p < 1024) ports;

    # Services known to fork worker processes (need clone/wait4 syscalls).
    forkingServices = [
      "nginx"
      "httpd"
      "postgresql"
      "named"
      "postfix"
    ];

    # Extract port from a healthcheck command's URL (localhost/127.0.0.1).
    # Returns int or null.
    healthcheckPort =
      healthCmd:
      let
        urlArgs = builtins.filter (
          arg: lib.hasInfix "://localhost" arg || lib.hasInfix "://127.0.0.1" arg
        ) healthCmd;
        url = if urlArgs != [ ] then builtins.head urlArgs else "";
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

    # Check if any healthcheck URL argument uses HTTPS.
    healthcheckHasHttps = healthCmd: lib.any (arg: lib.hasInfix "https://" arg) healthCmd;

    # Check if any healthcheck argument is -k or --insecure.
    healthcheckHasInsecureFlag = healthCmd: lib.any (arg: arg == "-k" || arg == "--insecure") healthCmd;

    # Check if healthcheck URLs reference a hostname (not localhost/127.0.0.1/[::1]).
    healthcheckUsesHostname =
      healthCmd:
      let
        urlArgs = builtins.filter (arg: lib.hasInfix "://" arg) healthCmd;
      in
      urlArgs != [ ]
      && !(lib.any (
        arg:
        lib.hasInfix "://localhost" arg || lib.hasInfix "://127.0.0.1" arg || lib.hasInfix "://[::1]" arg
      ) urlArgs);

    # Derive writable directory paths from systemd service data.
    writableDirs =
      serviceData:
      if serviceData != null then
        (map (d: "/run/${d}") (serviceData.runtimeDirs or [ ]))
        ++ (map (d: "/var/lib/${d}") (serviceData.stateDirs or [ ]))
        ++ (map (d: "/var/cache/${d}") (serviceData.cacheDirs or [ ]))
        ++ (map (d: "/var/log/${d}") (serviceData.logDirs or [ ]))
      else
        [ ];

    # -- Orchestrator --

    # Run all integration checks for a container.
    #
    # Arguments:
    #   name            - container attribute name
    #   containerConfig - resolved container options (package, isRoot, hardening, ports, etc.)
    #   evalOutput      - NixOS eval _output (or null for legacy path)
    #   mainService     - nixosConfig.mainService (or null)
    #   enabled         - whether nixosConfig is active
    runChecks =
      {
        name,
        containerConfig,
        evalOutput,
        mainService ? null,
        enabled ? false,
      }:
      let
        out = evalOutput;
        servicePackage = out.servicePackage or null;
        serviceType =
          if out.serviceData or null != null then out.serviceData.serviceType or "simple" else "simple";

        # -- Port/privilege coherence --
        explicitPorts = map self.parsePortInt (containerConfig.ports or [ ]);
        detectedPorts = out.detectedPorts or [ ];
        allPorts = lib.unique (explicitPorts ++ detectedPorts);
        privilegedPorts = self.extractPrivilegedPorts allPorts;
        hasPrivilegedPorts = privilegedPorts != [ ];
        hasPorts = allPorts != [ ];

        h = containerConfig.hardening;
        capsAdd = h.capabilities.add or [ ];
        capsDrop = h.capabilities.drop or [ ];
        hasNetBindService = lib.elem "NET_BIND_SERVICE" capsAdd;
        dropsAll = lib.elem "ALL" capsDrop;

        # -- Seccomp --
        seccompEnabled = h.enable && h.seccomp.enable;
        seccompProfile = h.seccomp.profile or "moderate";
        isStrictSeccomp = seccompEnabled && seccompProfile == "strict";
        serviceNeedsForking = mainService != null && lib.elem mainService self.forkingServices;

        # -- Landlock --
        landlockEnabled = h.enable && h.landlock.enable;
        landlockTcpBind = h.landlock.allowedTcpBind or [ ];
        landlockTcpConnect = h.landlock.allowedTcpConnect or [ ];
        missingBindPorts = builtins.filter (p: !(lib.elem p landlockTcpBind)) detectedPorts;

        # -- Healthcheck --
        healthcheck = out.healthcheck or null;
        healthCmd = if healthcheck != null then healthcheck.command or [ ] else [ ];
        healthCmdStr = lib.concatStringsSep " " healthCmd;
        hcPort = self.healthcheckPort healthCmd;
        missingHealthcheckConnect =
          landlockEnabled
          && hcPort != null
          && !(lib.elem hcPort landlockTcpConnect)
          && !(lib.elem hcPort landlockTcpBind);

        # -- Read-only rootfs + writable dirs --
        serviceData = out.serviceData or null;
        wDirs = self.writableDirs serviceData;
        declaredVolumes = out.declaredVolumes or [ ];
        uncoveredWriteDirs = builtins.filter (d: !(lib.elem d declaredVolumes) && d != "/tmp") wDirs;

        # -- Condition flags --
        packageConflict =
          enabled
          && mainService != null
          && containerConfig.package != null
          && servicePackage != null
          && containerConfig.package != servicePackage;
        isForkingService = enabled && mainService != null && serviceType == "forking";
        privilegedPortViolation =
          enabled && h.enable && !containerConfig.isRoot && hasPrivilegedPorts && !hasNetBindService;
        rootDroppedBindViolation =
          enabled
          && h.enable
          && containerConfig.isRoot
          && hasPrivilegedPorts
          && dropsAll
          && !hasNetBindService;
        portList = lib.concatMapStringsSep ", " toString privilegedPorts;
        seccompBlocksNetworking = enabled && isStrictSeccomp && hasPorts;
        seccompBlocksForking = enabled && isStrictSeccomp && serviceNeedsForking;
        landlockMissingBindPorts = enabled && landlockEnabled && missingBindPorts != [ ];
        missingBindList = lib.concatMapStringsSep ", " toString missingBindPorts;
        landlockBlocksHealthcheck = enabled && missingHealthcheckConnect;
        tlsBlocksHealthcheck =
          enabled
          && (h.noTlsTrustStore or false)
          && self.healthcheckHasHttps healthCmd
          && !(self.healthcheckHasInsecureFlag healthCmd);
        dnsBlocksHealthcheck = enabled && (h.disableDns or false) && self.healthcheckUsesHostname healthCmd;
        rootfsBlocksWrites = enabled && (h.readOnlyRootfs or false) && uncoveredWriteDirs != [ ];
        uncoveredDirList = lib.concatMapStringsSep ", " (d: "\"${d}\"") uncoveredWriteDirs;

        # -- nix.hostStore vs installNix mutual exclusion --
        nixStoreConflict = self.hasNixStoreConflict containerConfig;
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
            targets port ${toString hcPort} which is not in `hardening.landlock.allowedTcpConnect`.
            The healthcheck will fail at runtime. Fix:
              hardening.landlock.allowedTcpConnect = [ ${toString hcPort} ];
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
      )
      # -- nix.hostStore + installNix conflict (error) --
      + (
        if nixStoreConflict then
          throw ''
            Container "${name}": `nix.hostStore` and `installNix` are mutually exclusive.
            - Use `nix.hostStore = true` to bind-mount the host Nix store (lightweight).
            - Use `installNix = true` to embed a self-contained Nix in the image.
          ''
        else
          ""
      );
  };
in
self
