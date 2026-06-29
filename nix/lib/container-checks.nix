# Shared container integration checks.
#
# Pure function library that validates container configuration coherence.
# Called from both flake-parts integration.nix and deploy nixos-integration.nix.
#
# Top-level helpers are reusable and wrapped by nix-lib (nix/modules/oci/lib/checks.nix).
# `runChecks` orchestrates all checks and returns ""/throws/traces.
#
# Check logic is split into groups under ./container-checks/.
{ lib }:
let
  ociLib = import ./oci.nix { inherit lib; };

  # Load check groups, each is: { lib, helpers } -> ctx -> string
  checkGroups =
    let
      args = {
        inherit lib;
        helpers = self;
      };
    in
    map (f: import f args) [
      ./container-checks/entrypoint.nix
      ./container-checks/ports.nix
      ./container-checks/seccomp.nix
      ./container-checks/healthcheck.nix
      ./container-checks/rootfs.nix
      ./container-checks/capabilities.nix
      ./container-checks/nix-store.nix
      ./container-checks/layers.nix
      ./container-checks/hwcaps.nix
    ];

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

        # Shared computed state passed to all check groups.
        explicitPorts = map self.parsePortInt (containerConfig.ports or [ ]);
        detectedPorts = out.detectedPorts or [ ];
        allPorts = lib.unique (explicitPorts ++ detectedPorts);
        hasPorts = allPorts != [ ];

        healthcheck = out.healthcheck or null;
        healthCmd = if healthcheck != null then healthcheck.command or [ ] else [ ];
        hcPort = self.healthcheckPort healthCmd;

        ctx = {
          inherit
            name
            containerConfig
            evalOutput
            mainService
            enabled
            system
            allPorts
            hasPorts
            detectedPorts
            healthCmd
            hcPort
            ;
        };
      in
      lib.concatStrings (map (check: check ctx) checkGroups);
  };
in
self
