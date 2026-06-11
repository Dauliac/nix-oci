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

    # Validate port mapping string format.
    # Expected: "host:container" or "host:container/proto".
    isValidPortSpec =
      spec:
      let
        parts = lib.splitString "/" spec;
        hostContainer = builtins.head parts;
        proto = if builtins.length parts == 2 then builtins.elemAt parts 1 else "tcp";
        hcParts = lib.splitString ":" hostContainer;
        allDigits = s: builtins.match "[0-9]+" s != null;
      in
      builtins.length hcParts == 2
      && allDigits (builtins.head hcParts)
      && allDigits (builtins.elemAt hcParts 1)
      && lib.elem proto [
        "tcp"
        "udp"
      ];

    # Extract host port from a port mapping spec (the part before ':').
    parseHostPort =
      spec:
      let
        hostContainer = builtins.head (lib.splitString "/" spec);
        hostStr = builtins.head (lib.splitString ":" hostContainer);
        parsed = builtins.tryEval (lib.toInt hostStr);
      in
      if parsed.success then parsed.value else null;

    # All valid Linux capabilities (man 7 capabilities).
    validCapabilities = [
      "ALL"
      "AUDIT_CONTROL"
      "AUDIT_READ"
      "AUDIT_WRITE"
      "BLOCK_SUSPEND"
      "BPF"
      "CHECKPOINT_RESTORE"
      "CHOWN"
      "DAC_OVERRIDE"
      "DAC_READ_SEARCH"
      "FOWNER"
      "FSETID"
      "IPC_LOCK"
      "IPC_OWNER"
      "KILL"
      "LEASE"
      "LINUX_IMMUTABLE"
      "MAC_ADMIN"
      "MAC_OVERRIDE"
      "MKNOD"
      "NET_ADMIN"
      "NET_BIND_SERVICE"
      "NET_BROADCAST"
      "NET_RAW"
      "PERFMON"
      "SETFCAP"
      "SETGID"
      "SETPCAP"
      "SETUID"
      "SYS_ADMIN"
      "SYS_BOOT"
      "SYS_CHROOT"
      "SYS_MODULE"
      "SYS_NICE"
      "SYS_PACCT"
      "SYS_PTRACE"
      "SYS_RAWIO"
      "SYS_RESOURCE"
      "SYS_TIME"
      "SYS_TTY_CONFIG"
      "SYSLOG"
      "WAKE_ALARM"
    ];

    # Valid hwcaps levels per architecture (static, matches arch.nix).
    hwcapsLevelsForSystem = {
      "x86_64-linux" = [
        "x86-64-v2"
        "x86-64-v3"
        "x86-64-v4"
      ];
      "aarch64-linux" = [ ];
      "armv7l-linux" = [ ];
      "riscv64-linux" = [ ];
    };

    # -- Orchestrator --

    # Run all integration checks for a container.
    #
    # Arguments:
    #   name            - container attribute name
    #   containerConfig - resolved container options (package, isRoot, hardening, ports, etc.)
    #   evalOutput      - NixOS eval _output (or null for legacy path)
    #   mainService     - nixosConfig.mainService (or null)
    #   enabled         - whether nixosConfig is active
    #   system          - Nix system string (optional, for arch-specific checks)
    runChecks =
      {
        name,
        containerConfig,
        evalOutput,
        mainService ? null,
        enabled ? false,
        system ? null,
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

        # -- Port format validation --
        invalidPorts = builtins.filter (p: !(self.isValidPortSpec p)) (containerConfig.ports or [ ]);

        # -- Empty entrypoint --
        emptyEntrypoint =
          enabled
          && mainService == null
          && containerConfig.package == null
          && (containerConfig.entrypoint or [ ]) == [ ];

        # -- layerStrategy without optimizeLayers --
        layerStrategyIgnored =
          !(containerConfig.optimizeLayers or false)
          && (containerConfig.layerStrategy or "fine-grained") != "fine-grained";

        # -- LD_PRELOAD seccomp strict conflict --
        allocatorSeccompConflict =
          enabled && isStrictSeccomp && (containerConfig.performance or { }).allocator or null != null;

        # -- hwcaps architecture validation --
        perf = containerConfig.performance or { };
        hwcaps = perf.hwcaps or { };
        hwcapsEnabled = hwcaps.enable or false;
        hwcapsLevels = hwcaps.levels or [ ];
        validLevels = if system != null then self.hwcapsLevelsForSystem.${system} or [ ] else [ ];
        hwcapsUnsupported = system != null && hwcapsEnabled && validLevels == [ ];
        invalidHwcapsLevels =
          if system != null && hwcapsEnabled && validLevels != [ ] then
            builtins.filter (l: !(lib.elem l validLevels)) hwcapsLevels
          else
            [ ];

        # -- healthcheck port not in declared/detected ports --
        healthcheckPortUncovered =
          enabled && hcPort != null && allPorts != [ ] && !(lib.elem hcPort allPorts);

        # -- Duplicate host port mappings --
        hostPorts = builtins.filter (p: p != null) (map self.parseHostPort (containerConfig.ports or [ ]));
        uniqueHostPorts = lib.unique hostPorts;
        duplicateHostPorts = builtins.filter (p: lib.count (x: x == p) hostPorts > 1) uniqueHostPorts;

        # -- Invalid capability names --
        allCaps = capsAdd ++ capsDrop;
        invalidCaps = builtins.filter (c: !(lib.elem c self.validCapabilities)) allCaps;
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
      )
      # -- Invalid port format (error) --
      + (
        if invalidPorts != [ ] then
          throw ''
            Container "${name}": invalid port mapping format: ${
              lib.concatStringsSep ", " (map (p: ''"${p}"'') invalidPorts)
            }.
            Expected format: "hostPort:containerPort" or "hostPort:containerPort/proto"
            where proto is "tcp" or "udp".
            Examples: "8080:8080", "443:443/tcp", "5353:53/udp"
          ''
        else
          ""
      )
      # -- Empty entrypoint (error) --
      + (
        if emptyEntrypoint then
          throw ''
            Container "${name}": no entrypoint defined. The container has no way to start.
            None of the following are set:
              - `package` (with meta.mainProgram)
              - `nixosConfig.mainService` (auto-derives entrypoint from NixOS service)
              - `entrypoint` (explicit command list)
            Fix: set at least one of these options.
          ''
        else
          ""
      )
      # -- layerStrategy without optimizeLayers (warning) --
      + (
        if layerStrategyIgnored then
          builtins.trace ''
            WARNING: Container "${name}": `layerStrategy = "${
              containerConfig.layerStrategy or "fine-grained"
            }"` is set
            but `optimizeLayers = false`. The layerStrategy only takes effect when
            `optimizeLayers = true`. Fix: set `optimizeLayers = true` or remove `layerStrategy`.
          '' ""
        else
          ""
      )
      # -- LD_PRELOAD + seccomp strict conflict (error) --
      + (
        if allocatorSeccompConflict then
          throw ''
            Container "${name}": `performance.allocator = "${
              (containerConfig.performance or { }).allocator or ""
            }"` uses
            LD_PRELOAD but seccomp profile "strict" does not allow the mmap/mprotect
            patterns needed by dynamic library loading. The allocator will fail to load.
            Fix with one of:
              - Use `hardening.seccomp.profile = "web-server"` or `"moderate"`
              - Disable the custom allocator
          ''
        else
          ""
      )
      # -- hwcaps on unsupported architecture (error) --
      + (
        if hwcapsUnsupported then
          throw ''
            Container "${name}": `performance.hwcaps.enable = true` but architecture
            "${system}" does not support glibc-hwcaps. Only x86_64-linux supports
            hwcaps levels (x86-64-v2, x86-64-v3, x86-64-v4).
            Fix: remove `performance.hwcaps.enable` or set it to `false` for this arch.
          ''
        else
          ""
      )
      # -- hwcaps invalid levels for architecture (error) --
      + (
        if invalidHwcapsLevels != [ ] then
          throw ''
            Container "${name}": invalid hwcaps levels for ${toString system}: ${
              lib.concatStringsSep ", " (map (l: ''"${l}"'') invalidHwcapsLevels)
            }.
            Valid levels for ${toString system}: ${lib.concatStringsSep ", " validLevels}
          ''
        else
          ""
      )
      # -- healthcheck port not in declared/detected ports (warning) --
      + (
        if healthcheckPortUncovered then
          builtins.trace ''
            WARNING: Container "${name}": healthcheck targets port ${toString hcPort} but this
            port is not in the container's declared or detected ports: ${
              lib.concatMapStringsSep ", " toString allPorts
            }.
            This may indicate the healthcheck is checking an unreachable endpoint.
            Fix: add "${toString hcPort}" to `ports` or verify the healthcheck URL.
          '' ""
        else
          ""
      )
      # -- Duplicate host port mappings (error) --
      + (
        if duplicateHostPorts != [ ] then
          throw ''
            Container "${name}": duplicate host port(s): ${
              lib.concatMapStringsSep ", " toString duplicateHostPorts
            }.
            Each host port can only be bound once. Multiple containers or mappings
            using the same host port will fail at runtime.
            Fix: use unique host ports for each mapping.
          ''
        else
          ""
      )
      # -- Invalid capability names (error) --
      + (
        if invalidCaps != [ ] then
          throw ''
            Container "${name}": invalid Linux capability name(s): ${lib.concatStringsSep ", " invalidCaps}.
            Valid capabilities: ALL, CHOWN, DAC_OVERRIDE, FOWNER, FSETID, KILL, SETGID,
            SETUID, SETPCAP, NET_BIND_SERVICE, NET_RAW, NET_ADMIN, SYS_CHROOT,
            SYS_ADMIN, SYS_PTRACE, MKNOD, AUDIT_WRITE, SETFCAP, ...
            See: man 7 capabilities
          ''
        else
          ""
      );
  };
in
self
