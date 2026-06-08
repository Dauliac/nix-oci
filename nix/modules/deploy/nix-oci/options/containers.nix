# oci.containers — registered for NixOS, home-manager, and system-manager.
#
# Submodule imports SHARED option definitions from oci/containers/_options/
# (same source of truth as flake-parts) + deploy-specific extensions from _containers/.
# nix2container and ociLib are threaded into the submodule via specialArgs.
{ import-tree, ... }:
let
  # Shared core options (package, dependencies, isRoot, entrypoint, user, name, tag, etc.)
  sharedOptions = import-tree ../../../oci/containers/_options;
  # Deploy-specific extensions (autoStart, volumes, image, image-ref, _defaults)
  deployExtensions = import-tree ./_containers;

  mkOciLib =
    lib:
    let
      parseContainerPort =
        portSpec:
        let
          parts = lib.splitString ":" portSpec;
          raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
        in
        if lib.hasInfix "/" raw then raw else "${raw}/tcp";

      mkExposedPorts =
        ports: builtins.listToAttrs (map (p: lib.nameValuePair (parseContainerPort p) { }) ports);

      parseHostPort =
        portSpec:
        let
          raw = builtins.head (lib.splitString ":" portSpec);
          clean = builtins.head (lib.splitString "/" raw);
        in
        lib.toInt clean;

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
          configFiles,
          isRoot,
          user,
          pkgs,
        }:
        pkgs.buildEnv {
          name = "oci-root-${name}";
          paths =
            (lib.optional (package != null) package)
            ++ dependencies
            ++ configFiles
            ++ (mkShadowSetup {
              inherit isRoot user pkgs;
              runtimeShell = pkgs.runtimeShell;
            });
          pathsToLink = [
            "/bin"
            "/lib"
            "/etc"
            "/home"
          ];
          ignoreCollisions = true;
        };
      # Layer-building helpers for deploy images.
      # Uses the same fold pattern as flake-parts mkImageLayers.

      # Build a deps layer-def (attrset, not built) for the fold chain.
      mkDepsLayerDef =
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

      # Build an app layer-def for the fold chain.
      mkAppLayerDef =
        { copyToRoot }:
        {
          inherit copyToRoot;
        };

      # Fold layer-defs with deduplication: each layer references all
      # prior layers so nix2container excludes already-covered store paths.
      foldImageLayers =
        {
          nix2container,
          layerDefs,
        }:
        let
          mergeToLayer =
            priorLayers: layerDef:
            let
              layer = nix2container.buildLayer (layerDef // { layers = priorLayers; });
            in
            priorLayers ++ [ layer ];
        in
        lib.foldl mergeToLayer [ ] layerDefs;

      # Compose the full deduplicated layer stack for a deploy image.
      # Ordering: deps (most stable) → app root (changes on rebuild).
      mkImageLayers =
        {
          pkgs,
          nix2container,
          dependencies,
          rootPaths,
          layerStrategy ? "fine-grained",
        }:
        let
          depsLayerDefs =
            if dependencies != [ ] then
              [ (mkDepsLayerDef { inherit pkgs dependencies layerStrategy; }) ]
            else
              [ ];
          appLayerDefs = [ (mkAppLayerDef { copyToRoot = rootPaths; }) ];
        in
        foldImageLayers {
          inherit nix2container;
          layerDefs = depsLayerDefs ++ appLayerDefs;
        };
      # -- Hardening helpers --

      mkHardenedConfigs =
        {
          hardening,
          pkgs,
        }:
        lib.optionals hardening.enable (
          # NOTE: /etc/resolv.conf is NOT written — container runtimes always
          # bind-mount it at startup, masking any image content.
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
            "io.github.dauliac.nix-oci.hardening.enabled" = "true";
            "io.github.dauliac.nix-oci.hardening.no-new-privileges" =
              lib.boolToString hardening.noNewPrivileges;
            "io.github.dauliac.nix-oci.hardening.read-only-rootfs" = lib.boolToString hardening.readOnlyRootfs;
            "io.github.dauliac.nix-oci.hardening.capabilities-drop" =
              lib.concatStringsSep "," hardening.capabilities.drop;
          }
          // lib.optionalAttrs (hardening.capabilities.add != [ ]) {
            "io.github.dauliac.nix-oci.hardening.capabilities-add" =
              lib.concatStringsSep "," hardening.capabilities.add;
          }
          // lib.optionalAttrs hardening.seccomp.enable {
            "io.github.dauliac.nix-oci.hardening.seccomp-profile" = hardening.seccomp.profile;
          }
        );

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
          ns = "io.github.dauliac.nix-oci";
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
          // lib.optionalAttrs (description != null) { "org.opencontainers.image.description" = description; }
          // lib.optionalAttrs (spdxId != null) { "org.opencontainers.image.licenses" = spdxId; }
          // lib.optionalAttrs (homepage != null) { "org.opencontainers.image.url" = homepage; }
          // lib.optionalAttrs (authors != null) { "org.opencontainers.image.authors" = authors; }
          // lib.optionalAttrs (changelog != null) { "org.opencontainers.image.documentation" = changelog; };

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

      mkSeccompProfile =
        {
          name,
          hardening,
          pkgs,
        }:
        let
          archs = [
            "SCMP_ARCH_X86_64"
            "SCMP_ARCH_AARCH64"
          ];
          base = [
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
            "arch_prctl"
            "prctl"
            "prlimit64"
            "sched_getaffinity"
            "sched_yield"
          ];
          fileIo = [
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
          evLoop = [
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
          net = [
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
          threading = [
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
          fsWrite = [
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
          dangerous = [
            "acct"
            "add_key"
            "bpf"
            "clock_adjtime"
            "clock_settime"
            "create_module"
            "delete_module"
            "finit_module"
            "get_kernel_syms"
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
            "nfsservctl"
            "open_by_handle_at"
            "perf_event_open"
            "personality"
            "pivot_root"
            "process_vm_readv"
            "process_vm_writev"
            "ptrace"
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
              architectures = archs;
              syscalls = [
                {
                  names = lib.unique (base ++ fileIo ++ evLoop);
                  action = "SCMP_ACT_ALLOW";
                }
              ];
            };
            web-server = {
              defaultAction = "SCMP_ACT_ERRNO";
              architectures = archs;
              syscalls = [
                {
                  names = lib.unique (base ++ fileIo ++ evLoop ++ net ++ threading ++ fsWrite);
                  action = "SCMP_ACT_ALLOW";
                }
              ];
            };
            moderate = {
              defaultAction = "SCMP_ACT_ALLOW";
              architectures = archs;
              syscalls = [
                {
                  names = dangerous;
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
    in
    {
      inherit
        parseContainerPort
        mkExposedPorts
        parseHostPort
        mkShadowSetup
        mkRoot
        mkDepsLayerDef
        mkAppLayerDef
        foldImageLayers
        mkImageLayers
        mkHardenedConfigs
        mkHardeningLabels
        mkAutoLabels
        mkSeccompProfile
        ;
    };

  mod =
    {
      lib,
      pkgs,
      nix2container,
      ...
    }:
    let
      ociLib = mkOciLib lib;
    in
    {
      options.oci.containers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submoduleWith {
            modules = [
              sharedOptions
              deployExtensions
            ];
            specialArgs = {
              inherit pkgs nix2container ociLib;
            };
          }
        );
        default = { };
        description = ''
          OCI containers to build, load, and optionally run.
          Each entry builds an image via nix2container and creates
          a systemd service to load it into the container runtime.
        '';
      };
    };
in
{
  flake.modules.nixos.nix-oci-containers = mod;
  flake.modules.homeManager.nix-oci-containers = mod;
  flake.modules.systemManager.nix-oci-containers = mod;
}
