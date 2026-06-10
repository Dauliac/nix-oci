# Pure OCI library functions -- single source of truth.
#
# This file is a plain Nix attrset (NOT a module). It is imported by:
#   1. nix-lib module declarations (nix/modules/oci/lib/*.nix) -- for flake-parts consumers
#   2. Deploy module (nix/modules/deploy/nix-oci/options/containers.nix) -- for NixOS/HM consumers
#
# All functions receive their dependencies (lib, pkgs, etc.) as explicit arguments
# so they can be used in both contexts without requiring the module system.
{ lib }:
let
  ns = "io.github.dauliac.nix-oci";

  self = {
    # -- Package introspection --

    resolveMainProgram =
      package:
      if package.meta.mainProgram or null != null then
        package.meta.mainProgram
      else if package.pname or null != null then
        package.pname
      else
        (builtins.parseDrvName (package.name or "unknown")).name;

    # -- Port parsing --

    parseContainerPort =
      portSpec:
      let
        parts = lib.splitString ":" portSpec;
        raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
      in
      if lib.hasInfix "/" raw then raw else "${raw}/tcp";

    mkExposedPorts =
      ports: builtins.listToAttrs (map (p: lib.nameValuePair (self.parseContainerPort p) { }) ports);

    parseContainerPortInt =
      portSpec:
      let
        parts = lib.splitString ":" portSpec;
        raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
        clean = builtins.head (lib.splitString "/" raw);
      in
      lib.toInt clean;

    parseHostPort =
      portSpec:
      let
        raw = builtins.head (lib.splitString ":" portSpec);
        clean = builtins.head (lib.splitString "/" raw);
      in
      lib.toInt clean;

    # -- User / shadow setup --

    mkShadowSetup =
      {
        isRoot,
        user,
        runtimeShell,
        pkgs,
      }:
      if isRoot then
        [
          (pkgs.writeTextDir "etc/passwd" "root:x:0:0::/root:${runtimeShell}\n")
          (pkgs.writeTextDir "etc/shadow" "root:!x:::::::\n")
          (pkgs.writeTextDir "etc/group" "root:x:0:\n")
        ]
      else
        [
          (pkgs.writeTextDir "etc/passwd" ''
            root:x:0:0::/root:${runtimeShell}
            ${user}:x:4000:4000::/home/${user}:${runtimeShell}
          '')
          (pkgs.writeTextDir "etc/shadow" ''
            root:!x:::::::
            ${user}:!:::::::
          '')
          (pkgs.writeTextDir "etc/group" ''
            root:x:0:
            ${user}:x:4000:
          '')
          (pkgs.runCommand "home-${user}" { } ''
            mkdir -p $out/home/${user}
          '')
        ];

    mkRoot =
      {
        name,
        package,
        dependencies,
        isRoot,
        user,
        pkgs,
      }:
      pkgs.buildEnv {
        name = "oci-root-${name}";
        paths =
          (lib.optional (package != null) package)
          ++ dependencies
          ++ (self.mkShadowSetup {
            inherit isRoot user pkgs;
            runtimeShell = pkgs.runtimeShell;
          });
        pathsToLink = [
          "/bin"
          "/lib"
          "/etc"
          "/home"
          "/var"
        ];
        ignoreCollisions = true;
      };

    # -- Sandbox --

    mkSandboxScript =
      {
        name,
        rootFilesystem,
        entrypoint ? [ ],
        environment ? { },
        user ? "root",
        isRoot ? true,
        workingDir ? null,
        pkgs,
      }:
      let
        # Include coreutils and bash in PATH for interactive exploration.
        # Container's /bin takes precedence (listed first).
        sandboxPath = "/bin:${pkgs.coreutils}/bin:${pkgs.bashInteractive}/bin";

        envFlags = lib.concatStringsSep " \\\n    " (
          [ "--setenv PATH ${lib.escapeShellArg sandboxPath}" ]
          ++ lib.mapAttrsToList (k: v: "--setenv ${lib.escapeShellArg k} ${lib.escapeShellArg v}") environment
        );

        homeDir = if isRoot then "/root" else "/home/${user}";

        userFlags = if isRoot then "--uid 0 --gid 0" else "--unshare-user --uid 4000 --gid 4000";

        workDirFlag = lib.optionalString (workingDir != null) "--chdir ${lib.escapeShellArg workingDir}";

        shellCmd = "${pkgs.bashInteractive}/bin/bash";
      in
      pkgs.writeShellScriptBin "oci-sandbox-${name}" ''
        set -euo pipefail
        root="${rootFilesystem}"

        if [ $# -gt 0 ]; then
          cmd=("$@")
        else
          cmd=("${shellCmd}")
        fi

        # Copy home directory to a writable tmpdir so tools like starship,
        # git, bash history, etc. can write to ~/.cache, ~/.local, etc.
        # The source is a Nix store path (read-only); the copy is writable.
        sandbox_home=$(mktemp -d)
        trap 'rm -rf "$sandbox_home"' EXIT
        if [ -d "$root/home" ]; then
          ${pkgs.coreutils}/bin/cp -rL "$root/home/." "$sandbox_home/" 2>/dev/null || true
          ${pkgs.coreutils}/bin/chmod -R u+w "$sandbox_home" 2>/dev/null || true
        fi
        # Same for /root when running as root
        sandbox_root=$(mktemp -d)
        trap 'rm -rf "$sandbox_home" "$sandbox_root"' EXIT
        if [ -d "$root/root" ]; then
          ${pkgs.coreutils}/bin/cp -rL "$root/root/." "$sandbox_root/" 2>/dev/null || true
          ${pkgs.coreutils}/bin/chmod -R u+w "$sandbox_root" 2>/dev/null || true
        fi

        exec ${pkgs.bubblewrap}/bin/bwrap \
          --ro-bind /nix/store /nix/store \
          --ro-bind "$root/bin" /bin \
          --ro-bind "$root/lib" /lib \
          --ro-bind "$root/etc" /etc \
          --bind "$sandbox_home" /home \
          --bind "$sandbox_root" /root \
          --bind-try "$root/var" /var \
          --tmpfs /tmp \
          --proc /proc \
          --dev /dev \
          --unshare-pid \
          --die-with-parent \
          --clearenv \
          ${envFlags} \
          --setenv HOME "${homeDir}" \
          --setenv USER "${user}" \
          --setenv TERM "''${TERM:-xterm}" \
          ${userFlags} \
          ${workDirFlag} \
          "''${cmd[@]}"
      '';

    # -- Hardening --

    mkHardenedConfigs =
      {
        hardening,
        pkgs,
      }:
      lib.optionals hardening.enable (
        lib.optionals hardening.disableDns [
          (pkgs.writeTextDir "etc/nsswitch.conf" ''
            passwd:    files
            group:     files
            shadow:    files
            hosts:     files
            networks:  files
            ethers:    files
            services:  files
            protocols: files
            rpc:       files
          '')
        ]
        ++ lib.optionals hardening.noTlsTrustStore [
          (pkgs.writeTextDir "etc/ssl/certs/ca-bundle.crt" "# TLS trust store removed by nix-oci hardening\n")
        ]
      );

    mkHardeningLabels =
      { hardening }:
      lib.optionalAttrs hardening.enable (
        {
          "${ns}.hardening.enabled" = "true";
          "${ns}.hardening.no-new-privileges" = lib.boolToString hardening.noNewPrivileges;
          "${ns}.hardening.read-only-rootfs" = lib.boolToString hardening.readOnlyRootfs;
          "${ns}.hardening.capabilities-drop" = lib.concatStringsSep "," hardening.capabilities.drop;
        }
        // lib.optionalAttrs (hardening.capabilities.add != [ ]) {
          "${ns}.hardening.capabilities-add" = lib.concatStringsSep "," hardening.capabilities.add;
        }
        // lib.optionalAttrs hardening.seccomp.enable {
          "${ns}.hardening.seccomp-profile" = hardening.seccomp.profile;
        }
        // lib.optionalAttrs (hardening.landlock.enable or false) {
          "${ns}.hardening.landlock-enabled" = "true";
        }
      );

    # -- Layer building --

    mkDepsLayer =
      {
        pkgs,
        dependencies,
        layerStrategy ? "fine-grained",
      }:
      {
        copyToRoot = [
          (pkgs.buildEnv {
            name = "deps";
            paths = dependencies;
            pathsToLink = [
              "/bin"
              "/lib"
              "/etc"
            ];
            ignoreCollisions = true;
          })
        ];
      }
      // lib.optionalAttrs (layerStrategy == "fine-grained") {
        maxLayers = 80;
      };

    mkAppLayer =
      { copyToRoot }:
      {
        inherit copyToRoot;
      };

    foldImageLayers =
      {
        nix2container,
        layerDefs,
        prependBuiltLayers ? [ ],
      }:
      let
        mergeToLayer =
          priorLayers: layerDef:
          let
            layer = nix2container.buildLayer (layerDef // { layers = priorLayers; });
          in
          priorLayers ++ [ layer ];
      in
      lib.foldl mergeToLayer prependBuiltLayers layerDefs;

    mkImageLayers =
      {
        pkgs,
        nix2container,
        dependencies ? [ ],
        rootPaths ? [ ],
        layerStrategy ? "fine-grained",
        prependLayerDefs ? [ ],
        prependBuiltLayers ? [ ],
      }:
      let
        depsLayerDefs =
          if dependencies != [ ] then
            [
              (self.mkDepsLayer {
                inherit pkgs dependencies layerStrategy;
              })
            ]
          else
            [ ];
        appLayerDefs = if rootPaths != [ ] then [ (self.mkAppLayer { copyToRoot = rootPaths; }) ] else [ ];
        allLayerDefs = prependLayerDefs ++ depsLayerDefs ++ appLayerDefs;
      in
      self.foldImageLayers {
        inherit nix2container prependBuiltLayers;
        layerDefs = allLayerDefs;
      };

    # -- Labels --

    mkAutoLabels =
      {
        name,
        tag,
        package ? null,
        isRoot ? false,
        optimizeLayers ? false,
        layerStrategy ? "fine-grained",
        hardening ? {
          enable = false;
        },
        ports ? [ ],
        dependencies ? [ ],
        system ? "unknown",
        autoLabels ? true,
      }:
      let
        meta = if package != null then (package.meta or { }) else { };
        pname = if package != null then (package.pname or null) else null;
        version = if package != null then (package.version or null) else null;
        mainProgram = if package != null then (meta.mainProgram or (package.pname or null)) else null;
        description = meta.description or null;
        homepage = meta.homepage or null;
        changelog = meta.changelog or null;
        rawLicense = meta.license or null;
        spdxId =
          if rawLicense == null then
            null
          else if builtins.isList rawLicense then
            let
              ids = builtins.filter (x: x != null) (map (l: l.spdxId or null) rawLicense);
            in
            if ids == [ ] then null else lib.concatStringsSep " AND " ids
          else
            rawLicense.spdxId or null;
        rawMaintainers = meta.maintainers or [ ];
        maintainerNames = builtins.filter (x: x != null) (
          map (m: m.name or (m.github or null)) rawMaintainers
        );
        authors = if maintainerNames == [ ] then null else lib.concatStringsSep ", " maintainerNames;

        ociAnnotations = {
          "org.opencontainers.image.title" = name;
          "org.opencontainers.image.base.name" = "scratch";
        }
        // lib.optionalAttrs (tag != "latest") { "org.opencontainers.image.version" = tag; }
        // lib.optionalAttrs (version != null && tag == "latest") {
          "org.opencontainers.image.version" = version;
        }
        // lib.optionalAttrs (description != null) {
          "org.opencontainers.image.description" = description;
        }
        // lib.optionalAttrs (spdxId != null) { "org.opencontainers.image.licenses" = spdxId; }
        // lib.optionalAttrs (homepage != null) { "org.opencontainers.image.url" = homepage; }
        // lib.optionalAttrs (authors != null) { "org.opencontainers.image.authors" = authors; }
        // lib.optionalAttrs (changelog != null) {
          "org.opencontainers.image.documentation" = changelog;
        };

        buildInfo = {
          "${ns}.build.system" = system;
          "${ns}.build.optimized-layers" = lib.boolToString optimizeLayers;
          "${ns}.build.layer-strategy" = layerStrategy;
          "${ns}.build.reproducible" = "true";
        };

        hardeningEnabled = hardening.enable or false;
        hardeningLabels = lib.optionalAttrs hardeningEnabled (
          {
            "${ns}.hardening.enabled" = "true";
            "${ns}.hardening.no-new-privileges" = lib.boolToString (hardening.noNewPrivileges or true);
            "${ns}.hardening.read-only-rootfs" = lib.boolToString (hardening.readOnlyRootfs or true);
            "${ns}.hardening.capabilities-drop" = lib.concatStringsSep "," (
              hardening.capabilities.drop or [ "ALL" ]
            );
          }
          // lib.optionalAttrs ((hardening.capabilities.add or [ ]) != [ ]) {
            "${ns}.hardening.capabilities-add" = lib.concatStringsSep "," hardening.capabilities.add;
          }
          // lib.optionalAttrs (hardening.seccomp.enable or false) {
            "${ns}.hardening.seccomp-profile" = hardening.seccomp.profile or "moderate";
          }
          // lib.optionalAttrs (hardening.landlock.enable or false) {
            "${ns}.hardening.landlock-enabled" = "true";
          }
          // lib.optionalAttrs (hardening.disableDns or false) {
            "${ns}.hardening.dns-disabled" = "true";
          }
          // lib.optionalAttrs (hardening.noTlsTrustStore or false) {
            "${ns}.hardening.tls-trust-store-removed" = "true";
          }
        );

        pssLevel =
          if
            hardeningEnabled
            && !isRoot
            && (hardening.noNewPrivileges or true)
            && builtins.elem "ALL" (hardening.capabilities.drop or [ ])
            && (hardening.seccomp.enable or false)
            && (hardening.readOnlyRootfs or true)
          then
            "restricted"
          else if hardeningEnabled then
            "baseline"
          else
            "privileged";
        pssLabel = lib.optionalAttrs hardeningEnabled {
          "${ns}.kubernetes.pod-security-standard" = pssLevel;
        };

        uid = if isRoot then "0" else "4000";
        gid = if isRoot then "0" else "4000";
        kubernetesSecurityContext = {
          "${ns}.kubernetes.run-as-user" = uid;
          "${ns}.kubernetes.run-as-group" = gid;
          "${ns}.kubernetes.fs-group" = gid;
        }
        // lib.optionalAttrs (hardeningEnabled && (hardening.seccomp.enable or false)) {
          "${ns}.kubernetes.seccomp-profile-type" = "RuntimeDefault";
        };

        parsePort =
          portSpec:
          let
            parts = lib.splitString ":" portSpec;
            raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
            portAndProto = lib.splitString "/" raw;
            port = builtins.head portAndProto;
            proto = if builtins.length portAndProto >= 2 then builtins.elemAt portAndProto 1 else "tcp";
          in
          {
            inherit port proto;
          };
        parsedPorts = map parsePort ports;
        tcpPorts = map (p: p.port) (builtins.filter (p: p.proto == "tcp") parsedPorts);
        udpPorts = map (p: p.port) (builtins.filter (p: p.proto == "udp") parsedPorts);
        networkLabels =
          lib.optionalAttrs (tcpPorts != [ ]) {
            "${ns}.network.tcp-ports" = lib.concatStringsSep "," tcpPorts;
          }
          // lib.optionalAttrs (udpPorts != [ ]) {
            "${ns}.network.udp-ports" = lib.concatStringsSep "," udpPorts;
          };

        nixIdentity =
          lib.optionalAttrs (pname != null) { "${ns}.nix.pname" = pname; }
          // lib.optionalAttrs (version != null) { "${ns}.nix.version" = version; }
          // lib.optionalAttrs (mainProgram != null) { "${ns}.nix.main-program" = mainProgram; }
          // lib.optionalAttrs (dependencies != [ ]) {
            "${ns}.nix.dependency-count" = toString (builtins.length dependencies);
          };

        knownVulns = meta.knownVulnerabilities or [ ];
        rawProvenance = meta.sourceProvenance or [ ];
        provenanceNames = builtins.filter (x: x != null) (
          map (p: p.shortName or (p.name or null)) rawProvenance
        );
        securityLabels =
          lib.optionalAttrs (knownVulns != [ ]) {
            "${ns}.security.known-vulnerabilities" = lib.concatStringsSep "," knownVulns;
            "${ns}.security.insecure" = "true";
          }
          // lib.optionalAttrs (provenanceNames != [ ]) {
            "${ns}.provenance.source-type" = lib.concatStringsSep "," provenanceNames;
          };

        runtimeInfo = {
          "${ns}.runtime.user" = if isRoot then "root" else "non-root";
          "${ns}.runtime.is-root" = lib.boolToString isRoot;
        };
      in
      if autoLabels then
        ociAnnotations
        // buildInfo
        // hardeningLabels
        // pssLabel
        // kubernetesSecurityContext
        // networkLabels
        // nixIdentity
        // securityLabels
        // runtimeInfo
      else
        { };

    # -- Seccomp --

    mkSeccompProfile =
      {
        name,
        hardening,
        pkgs,
      }:
      let
        architectures = [
          "SCMP_ARCH_X86_64"
          "SCMP_ARCH_AARCH64"
        ];
        baseSyscalls = [
          "exit"
          "exit_group"
          "read"
          "write"
          "close"
          "mmap"
          "mprotect"
          "munmap"
          "brk"
          "madvise"
          "mremap"
          "rt_sigaction"
          "rt_sigprocmask"
          "rt_sigreturn"
          "sigaltstack"
          "futex"
          "set_tid_address"
          "set_robust_list"
          "rseq"
          "clock_gettime"
          "clock_getres"
          "gettimeofday"
          "nanosleep"
          "clock_nanosleep"
          "getrandom"
          "getpid"
          "getppid"
          "gettid"
          "getuid"
          "getgid"
          "geteuid"
          "getegid"
          "getresuid"
          "getresgid"
          "arch_prctl"
          "prctl"
          "prlimit64"
          "sched_getaffinity"
          "sched_yield"
        ];
        fileIoSyscalls = [
          "openat"
          "fstat"
          "newfstatat"
          "statx"
          "lseek"
          "pread64"
          "pwrite64"
          "readv"
          "writev"
          "access"
          "faccessat"
          "faccessat2"
          "fcntl"
          "ioctl"
          "getdents64"
          "readlinkat"
          "pipe2"
          "dup"
          "dup2"
          "dup3"
          "statfs"
          "fstatfs"
          "getcwd"
          "uname"
          "sysinfo"
        ];
        eventLoopSyscalls = [
          "epoll_create1"
          "epoll_ctl"
          "epoll_pwait"
          "epoll_pwait2"
          "poll"
          "ppoll"
          "select"
          "pselect6"
          "eventfd2"
        ];
        networkSyscalls = [
          "socket"
          "socketpair"
          "bind"
          "listen"
          "accept4"
          "connect"
          "sendto"
          "recvfrom"
          "sendmsg"
          "recvmsg"
          "sendmmsg"
          "recvmmsg"
          "getsockname"
          "getpeername"
          "setsockopt"
          "getsockopt"
          "shutdown"
        ];
        threadingSyscalls = [
          "clone"
          "clone3"
          "wait4"
          "waitid"
          "tgkill"
          "timerfd_create"
          "timerfd_settime"
          "timerfd_gettime"
          "signalfd4"
          "splice"
          "sendfile"
          "mlock"
          "munlock"
        ];
        fsWriteSyscalls = [
          "fchmod"
          "fchown"
          "ftruncate"
          "fallocate"
          "fsync"
          "fdatasync"
          "flock"
          "rename"
          "renameat"
          "renameat2"
          "unlink"
          "unlinkat"
          "mkdir"
          "mkdirat"
          "chdir"
          "fchdir"
        ];
        dangerousSyscalls = [
          "acct"
          "add_key"
          "bpf"
          "clock_adjtime"
          "clock_settime"
          "create_module"
          "delete_module"
          "finit_module"
          "get_kernel_syms"
          "get_mempolicy"
          "init_module"
          "ioperm"
          "iopl"
          "kcmp"
          "kexec_file_load"
          "kexec_load"
          "keyctl"
          "lookup_dcookie"
          "mbind"
          "mount"
          "move_mount"
          "move_pages"
          "name_to_handle_at"
          "nfsservctl"
          "open_by_handle_at"
          "perf_event_open"
          "personality"
          "pivot_root"
          "process_vm_readv"
          "process_vm_writev"
          "ptrace"
          "query_module"
          "quotactl"
          "reboot"
          "request_key"
          "set_mempolicy"
          "setns"
          "settimeofday"
          "swapon"
          "swapoff"
          "sysfs"
          "_sysctl"
          "umount2"
          "unshare"
          "uselib"
          "userfaultfd"
          "ustat"
        ];
        profiles = {
          strict = {
            defaultAction = "SCMP_ACT_ERRNO";
            inherit architectures;
            syscalls = [
              {
                names = lib.unique (baseSyscalls ++ fileIoSyscalls ++ eventLoopSyscalls);
                action = "SCMP_ACT_ALLOW";
              }
            ];
          };
          web-server = {
            defaultAction = "SCMP_ACT_ERRNO";
            inherit architectures;
            syscalls = [
              {
                names = lib.unique (
                  baseSyscalls
                  ++ fileIoSyscalls
                  ++ eventLoopSyscalls
                  ++ networkSyscalls
                  ++ threadingSyscalls
                  ++ fsWriteSyscalls
                );
                action = "SCMP_ACT_ALLOW";
              }
            ];
          };
          moderate = {
            defaultAction = "SCMP_ACT_ALLOW";
            inherit architectures;
            syscalls = [
              {
                names = dangerousSyscalls;
                action = "SCMP_ACT_ERRNO";
              }
            ];
          };
        };
      in
      if hardening.seccomp.customProfileJson != null then
        hardening.seccomp.customProfileJson
      else
        pkgs.writeText "seccomp-${name}.json" (builtins.toJSON profiles.${hardening.seccomp.profile});

    # -- NixOS eval helpers (pure cores) --

    # Normalize a value to a list (null -> [], scalar -> [x], list -> list).
    toList =
      x:
      if builtins.isList x then
        x
      else if x == null then
        [ ]
      else
        [ x ];

    # Generate an entrypoint wrapper script from systemd service data.
    # serviceData is a plain attrset produced by extractServiceData in _nixos-oci/entrypoint.nix.
    mkEntrypointScript =
      {
        serviceData,
        pkgs,
      }:
      let
        mkDirs =
          prefix: dirs:
          lib.concatMapStringsSep "\n" (d: "${pkgs.coreutils}/bin/mkdir -p ${prefix}/${d}") dirs;
        mkEnvExports = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") serviceData.environment
        );
        validExecStartPre = builtins.filter (x: x != null && x != "") serviceData.execStartPre;
        mkExecStartPre = lib.concatMapStringsSep "\n" (
          cmd:
          let
            stripped = lib.removePrefix "-" (lib.removePrefix "+" cmd);
            ignoreFailure = lib.hasPrefix "-" cmd || lib.hasPrefix "+" cmd;
          in
          if ignoreFailure then "${stripped} || true" else stripped
        ) validExecStartPre;
      in
      pkgs.writeShellScript "container-entrypoint" ''
        set -euo pipefail
        ${lib.optionalString (serviceData.runtimeDirs != [ ]) (mkDirs "/run" serviceData.runtimeDirs)}
        ${lib.optionalString (serviceData.stateDirs != [ ]) (mkDirs "/var/lib" serviceData.stateDirs)}
        ${lib.optionalString (serviceData.cacheDirs != [ ]) (mkDirs "/var/cache" serviceData.cacheDirs)}
        ${lib.optionalString (serviceData.logDirs != [ ]) (mkDirs "/var/log" serviceData.logDirs)}
        ${lib.optionalString (mkEnvExports != "") mkEnvExports}
        ${lib.optionalString (serviceData.preStart != "") serviceData.preStart}
        ${lib.optionalString (mkExecStartPre != "") mkExecStartPre}
        exec ${serviceData.execStart}
      '';

    # Create a derivation from a NixOS environment.etc entry.
    mkEtcDerivation =
      {
        name,
        entry,
        pkgs,
      }:
      let
        safeName = builtins.replaceStrings [ "/" ] [ "-" ] name;
        mode = entry.mode or "0644";
        isSymlink = mode == "symlink" || mode == "direct-symlink";
      in
      pkgs.runCommand "etc-${safeName}" { } ''
        mkdir -p $out/etc/$(dirname "${name}")
        cp -L ${entry.source} $out/etc/${name}
        ${if isSymlink then "" else "chmod ${mode} $out/etc/${name}"}
      '';
  };
in
self
