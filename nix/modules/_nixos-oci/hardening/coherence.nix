# Cross-backend security coherence checks.
#
# Detects incoherent compositions between security backends:
#   seccomp ↔ capabilities ↔ Landlock ↔ DNS/TLS ↔ service detection
#
# Assertions = hard build failure (definite runtime breakage).
# Warnings   = soft trace (suspicious but possibly intentional).
#
# Categories:
#   P  = Phantom Permission  — backend A allows X, backend B silently blocks it
#   C  = Contradicted Intent — config implies X, but another setting negates it
#   D  = Dead Configuration  — setting has no runtime effect
#   S  = Semantic Conflict   — individually valid, collectively nonsensical
#   G  = Enforcement Gap     — important domain has no backend covering it
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container.hardening;

  inherit (lib)
    elem
    any
    concatStringsSep
    concatMapStringsSep
    optional
    optionals
    ;

  # -- Seccomp profile capability knowledge --
  # We generate the profiles, so we KNOW what each one allows.
  # "strict" is an allowlist of ~60 syscalls (base + fileIo + eventLoop).
  # "moderate" is a denylist (blocks dangerous syscalls, allows everything else).
  # The others are allowlists with progressively more syscall groups.
  profileHasNetwork =
    p:
    elem p [
      "web-server"
      "database"
      "gpu-compute"
      "moderate"
    ];
  profileHasThreading =
    p:
    elem p [
      "web-server"
      "database"
      "gpu-compute"
      "moderate"
    ];
  profileHasFsWrite =
    p:
    elem p [
      "web-server"
      "database"
      "gpu-compute"
      "moderate"
    ];

  # All non-moderate allowlist profiles include argument-level filters that
  # block socket(AF_PACKET) and socket(AF_NETLINK), and clone(CLONE_NEW*).
  # "moderate" blocks these via dangerousSyscalls denylist + arg filters.
  profileBlocksRawSocket = _p: true; # all profiles block AF_PACKET/AF_NETLINK
  profileBlocksNamespaceCreation = _p: true; # all profiles filter clone CLONE_NEW*

  # Dangerous syscalls explicitly blocked by "moderate" denylist AND omitted
  # from all allowlist profiles. These are always blocked regardless of profile.
  alwaysBlockedSyscalls = [
    "ptrace"
    "process_vm_readv"
    "process_vm_writev"
    "mount"
    "umount2"
    "pivot_root"
    "unshare"
    "setns"
    "init_module"
    "finit_module"
    "delete_module"
    "reboot"
    "kexec_load"
    "kexec_file_load"
    "ioperm"
    "iopl"
    "clock_settime"
    "settimeofday"
    "bpf"
  ];

  # -- Capability → syscall mapping --
  # When a capability is added but seccomp blocks the corresponding syscalls,
  # the capability is a phantom permission (no runtime effect, misleading config).
  capSyscallMap = {
    SYS_PTRACE = {
      syscalls = [
        "ptrace"
        "process_vm_readv"
        "process_vm_writev"
      ];
      desc = "ptrace and process memory access";
    };
    SYS_ADMIN = {
      syscalls = [
        "mount"
        "umount2"
        "pivot_root"
        "unshare"
        "setns"
      ];
      desc = "mount, unshare, pivot_root, namespace operations";
      extraNote = "Also blocked by clone CLONE_NEW* argument filter.";
    };
    SYS_MODULE = {
      syscalls = [
        "init_module"
        "finit_module"
        "delete_module"
      ];
      desc = "kernel module loading/unloading";
    };
    SYS_RAWIO = {
      syscalls = [
        "ioperm"
        "iopl"
      ];
      desc = "raw I/O port access";
    };
    SYS_TIME = {
      syscalls = [
        "clock_settime"
        "settimeofday"
      ];
      desc = "system clock modification";
    };
    SYS_BOOT = {
      syscalls = [
        "reboot"
        "kexec_load"
        "kexec_file_load"
      ];
      desc = "system reboot/kexec";
    };
  };

  # Check if a capability's syscalls are ALL blocked by seccomp.
  # For always-blocked syscalls, this is true regardless of profile.
  capIsPhantom =
    capName:
    let
      mapping = capSyscallMap.${capName} or null;
    in
    mapping != null && lib.all (s: elem s alwaysBlockedSyscalls) mapping.syscalls;

  phantomCaps = lib.filter (c: capIsPhantom c) cfg.capabilities.add;

  # -- Service detection (mirrors config.nix) --
  hasWebServer = (config.services.nginx.enable or false) || (config.services.httpd.enable or false);

  hasDatabase =
    (config.services.postgresql.enable or false) || ((config.services.redis.servers or { }) != { });

  detectedTcpBind =
    let
      nginxPorts =
        if config.services.nginx.enable or false then
          [ (config.services.nginx.defaultHTTPListenPort or 80) ]
        else
          [ ];
    in
    nginxPorts;

  allDetectedPorts = detectedTcpBind;

  # Capabilities that grant something seccomp doesn't even need to block
  # because the profile already omits the syscalls (allowlist profiles).
  # NET_RAW is special: all profiles block AF_PACKET/AF_NETLINK via arg filters.
  hasNetRawPhantom =
    cfg.seccomp.enable
    && elem "NET_RAW" cfg.capabilities.add
    && profileBlocksRawSocket cfg.seccomp.profile;

  # Port < 1024 without NET_BIND_SERVICE
  privilegedPorts = lib.filter (p: p < 1024) (cfg.landlock.allowedTcpBind ++ allDetectedPorts);

  hasPrivilegedPortWithoutCap =
    privilegedPorts != [ ]
    && (elem "ALL" cfg.capabilities.drop)
    && !(elem "NET_BIND_SERVICE" cfg.capabilities.add);
in
{
  config = lib.mkIf cfg.enable {
    # =====================================================================
    #  ASSERTIONS — hard build failure
    # =====================================================================
    assertions =
      # -- P1: Landlock TCP rules dead if seccomp blocks network syscalls --
      optional
        (
          cfg.seccomp.enable
          && cfg.seccomp.customProfileJson == null
          && cfg.landlock.enable
          && !(profileHasNetwork cfg.seccomp.profile)
          && (cfg.landlock.allowedTcpBind != [ ] || cfg.landlock.allowedTcpConnect != [ ])
        )
        {
          assertion = false;
          message = ''
            nix-oci coherence: Landlock allows TCP ports
            (bind: ${toString cfg.landlock.allowedTcpBind}, connect: ${toString cfg.landlock.allowedTcpConnect})
            but seccomp profile "${cfg.seccomp.profile}" blocks ALL network syscalls.
            Landlock TCP rules have NO EFFECT — seccomp intercepts first.
            Fix: use a network-capable profile (web-server, database, moderate)
            or remove the Landlock TCP rules.
          '';
        }
      # -- P2: NET_RAW capability dead under seccomp arg filters --
      ++ optional hasNetRawPhantom {
        assertion = false;
        message = ''
          nix-oci coherence: capabilities.add includes NET_RAW but seccomp
          profile "${cfg.seccomp.profile}" blocks socket(AF_PACKET) and
          socket(AF_NETLINK) via argument filtering.
          The capability has NO EFFECT — seccomp blocks raw socket creation.
          Fix: remove NET_RAW from capabilities.add, or use a custom seccomp
          profile that allows these address families.
        '';
      }
      # -- P3: Capabilities dead because seccomp blocks their syscalls --
      ++ optional (cfg.seccomp.enable && cfg.seccomp.customProfileJson == null && phantomCaps != [ ]) {
        assertion = false;
        message = ''
          nix-oci coherence: capabilities.add includes
          ${concatStringsSep ", " phantomCaps}
          but seccomp blocks the corresponding syscalls in ALL profiles:
          ${concatMapStringsSep "\n  " (
            c:
            let
              m = capSyscallMap.${c};
            in
            "${c}: ${m.desc} (${concatStringsSep ", " m.syscalls})"
            + (if m ? extraNote then " — ${m.extraNote}" else "")
          ) phantomCaps}
          These capabilities have NO EFFECT.
          Fix: remove them from capabilities.add (they provide no privilege)
          or use a custom seccomp profile.
        '';
      }
      # -- P4: Landlock write paths dead if seccomp blocks fsWrite syscalls --
      ++
        optional
          (
            cfg.seccomp.enable
            && cfg.seccomp.customProfileJson == null
            && cfg.landlock.enable
            && !(profileHasFsWrite cfg.seccomp.profile)
            && cfg.landlock.allowedWritePaths != [ ]
          )
          {
            assertion = false;
            message = ''
              nix-oci coherence: Landlock allows write to
              ${concatStringsSep ", " cfg.landlock.allowedWritePaths}
              but seccomp profile "${cfg.seccomp.profile}" blocks filesystem
              write syscalls (fchmod, ftruncate, rename, unlink, mkdir, ...).
              The Landlock write rules have NO EFFECT.
              Fix: use a write-capable profile (web-server, database, moderate).
            '';
          }
      # -- C1: Privileged ports without NET_BIND_SERVICE --
      ++ optional hasPrivilegedPortWithoutCap {
        assertion = false;
        message = ''
          nix-oci coherence: ports < 1024 are configured
          (${concatMapStringsSep ", " toString privilegedPorts})
          but capabilities drop ALL without adding NET_BIND_SERVICE.
          The kernel will reject bind() on these ports regardless of
          Landlock/seccomp allowing it.
          Fix: add "NET_BIND_SERVICE" to hardening.capabilities.add.
        '';
      }
      # -- C2: Custom seccomp JSON makes cross-checks opaque --
      ++
        optional
          (
            cfg.seccomp.enable
            && cfg.seccomp.customProfileJson != null
            && (cfg.landlock.enable || cfg.capabilities.add != [ ])
          )
          {
            assertion = false;
            message = ''
              nix-oci coherence: seccomp.customProfileJson overrides ALL computed
              seccomp rules. Cross-backend coherence with Landlock and capabilities
              CANNOT be verified — the custom profile may silently contradict them.
              Fix: remove Landlock/capability overrides when using custom seccomp
              JSON (you take full responsibility for coherence), or remove the
              custom JSON to use built-in profiles.
            '';
          }
      # -- S1: Strict seccomp profile contradicts detected web server --
      ++
        optional
          (
            cfg.seccomp.enable
            && cfg.seccomp.profile == "strict"
            && cfg.seccomp.customProfileJson == null
            && hasWebServer
          )
          {
            assertion = false;
            message = ''
              nix-oci coherence: seccomp.profile explicitly set to "strict" but a
              web server (nginx/httpd) is detected. The strict profile blocks ALL
              network, threading, and filesystem write syscalls — the web server
              WILL crash at startup.
              Fix: use "web-server" profile, or remove the explicit profile override
              (auto-detection would have chosen "web-server").
            '';
          }
      # -- S2: Strict seccomp profile contradicts detected database --
      ++
        optional
          (
            cfg.seccomp.enable
            && cfg.seccomp.profile == "strict"
            && cfg.seccomp.customProfileJson == null
            && hasDatabase
          )
          {
            assertion = false;
            message = ''
              nix-oci coherence: seccomp.profile explicitly set to "strict" but a
              database (PostgreSQL/Redis) is detected. The strict profile blocks
              network, threading, and filesystem write syscalls — the database
              WILL crash at startup.
              Fix: use "database" profile, or remove the explicit profile override
              (auto-detection would have chosen "database").
            '';
          }
      # -- S3: TLS trust store removed but Landlock allows HTTPS connect --
      ++
        optional
          (cfg.noTlsTrustStore && cfg.landlock.enable && any (p: p == 443) cfg.landlock.allowedTcpConnect)
          {
            assertion = false;
            message = ''
              nix-oci coherence: TLS trust store is removed but Landlock allows
              TCP connect to port 443 (HTTPS). TLS handshakes will fail without
              CA certificates, making the Landlock rule misleading.
              Fix: keep the trust store (noTlsTrustStore = false), or remove
              port 443 from landlock.allowedTcpConnect.
            '';
          }
      # -- S4: noNewPrivileges disabled with otherwise strict hardening --
      ++ optional (!cfg.noNewPrivileges && cfg.seccomp.enable && (elem "ALL" cfg.capabilities.drop)) {
        assertion = false;
        message = ''
          nix-oci coherence: seccomp and capability restrictions are active but
          noNewPrivileges = false. A setuid binary inside the container could
          bypass capability restrictions via execve privilege escalation.
          Fix: set noNewPrivileges = true (default), or acknowledge the risk
          by also relaxing capabilities.
        '';
      };

    # =====================================================================
    #  WARNINGS — soft trace, build succeeds
    # =====================================================================
    warnings =
      # -- D1: Landlock rules set but landlock.enable = false --
      optional
        (
          !cfg.landlock.enable
          && (
            cfg.landlock.allowedTcpBind != [ ]
            || cfg.landlock.allowedTcpConnect != [ ]
            || cfg.landlock.allowedWritePaths != [ ]
            || cfg.landlock.allowedReadPaths != [ ]
            || cfg.landlock.allowedExecutePaths != [ ]
          )
        )
        ''
          nix-oci coherence: Landlock rules are configured but
          landlock.enable = false. All Landlock rules have NO EFFECT.
          Fix: set landlock.enable = true, or remove the rules.
        ''
      # -- D2: Capabilities add without drop --
      ++ optional (cfg.capabilities.add != [ ] && cfg.capabilities.drop == [ ]) ''
        nix-oci coherence: capabilities.add = [${concatStringsSep " " cfg.capabilities.add}]
        but capabilities.drop is empty (default container caps remain).
        Adding capabilities on top of defaults is unusual — you may want
        drop = ["ALL"] then add back only what's needed.
      ''
      # -- D3: Seccomp audit mode --
      ++ optional (cfg.seccomp.enable && cfg.seccomp.mode == "audit") ''
        nix-oci coherence: seccomp.mode = "audit" — disallowed syscalls are
        LOGGED but NOT BLOCKED. This provides no runtime protection.
        Use mode = "enforce" for production deployments.
      ''
      # -- D4: readOnlyRootfs disabled with hardening enabled --
      ++ optional (!cfg.readOnlyRootfs) ''
        nix-oci coherence: hardening.enable = true but readOnlyRootfs = false.
        Attackers with initial access can write malware or achieve persistence
        on the container filesystem.
        Consider: readOnlyRootfs = true (default) with explicit writable mounts.
      ''
      # -- G1: Ports exposed without port-level restriction --
      ++ optional (allDetectedPorts != [ ] && !cfg.landlock.enable) ''
        nix-oci coherence: container exposes ports
        ${concatMapStringsSep ", " toString allDetectedPorts}
        but Landlock is not enabled for port-level network restriction.
        Seccomp allows all network syscalls in this profile.
        Consider: landlock.enable = true for TCP port allowlisting.
      ''
      # -- G2: No filesystem restriction beyond read-only rootfs --
      ++ optional (cfg.readOnlyRootfs && !cfg.landlock.enable) ''
        nix-oci coherence: rootfs is read-only but no fine-grained filesystem
        restriction (Landlock) is active. Tmpfs mounts and volumes are fully
        writable without path-level control.
        Consider: landlock.enable = true for path-level allowlisting.
      ''
      # -- G3: All enforcement backends weak or disabled --
      ++
        optional
          (
            (!cfg.seccomp.enable || cfg.seccomp.mode == "audit")
            && !cfg.landlock.enable
            && cfg.capabilities.drop == [ ]
          )
          ''
            nix-oci coherence: hardening.enable = true but ALL enforcement
            backends are disabled or in audit mode, and no capabilities are
            dropped. No meaningful runtime security restrictions are active.
          '';
  };
}
