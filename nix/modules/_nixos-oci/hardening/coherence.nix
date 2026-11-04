# Cross-backend security coherence checks.
#
# Detects incoherent compositions between security backends:
#   seccomp ↔ capabilities ↔ AppArmor ↔ DNS/TLS ↔ service detection
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

  # Deploy-time container runtime ("podman"/"docker"), injected via
  # _module.args by eval-container.nix (see its comment there). Read via
  # `config._module.args.X or default`, NOT a `backend ? null,` function
  # argument: nixpkgs resolves missing module-function arguments by
  # querying config._module.args unconditionally once it decides the
  # arg "is not externally provided", which ignores a `?` default and
  # throws "attribute 'backend' missing" for any caller that evaluates
  # this module without threading _module.args.backend (e.g. the
  # standalone coherence probe harness in
  # containers/_tests/invariant/_helpers.nix). Same pattern as `ociLib`
  # in deploy/nix-oci/options/containers.nix. null in contexts with no
  # backend selection, e.g. flake-side build-only containers -- the D1
  # check below simply never fires in that case.
  backend = config._module.args.backend or null;

  inherit (lib)
    elem
    concatStringsSep
    concatMapStringsSep
    optional
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

  # All non-moderate allowlist profiles include argument-level filters that
  # block socket(AF_PACKET) and socket(AF_NETLINK), and clone(CLONE_NEW*).
  # "moderate" blocks these via dangerousSyscalls denylist + arg filters.
  profileBlocksRawSocket = _p: true; # all profiles block AF_PACKET/AF_NETLINK

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
  privilegedPorts = lib.filter (p: p < 1024) allDetectedPorts;

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
      # -- P2: NET_RAW capability dead under seccomp arg filters --
      optional hasNetRawPhantom {
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
      # -- C1: Privileged ports without NET_BIND_SERVICE --
      ++ optional hasPrivilegedPortWithoutCap {
        assertion = false;
        message = ''
          nix-oci coherence: ports < 1024 are configured
          (${concatMapStringsSep ", " toString privilegedPorts})
          but capabilities drop ALL without adding NET_BIND_SERVICE.
          The kernel will reject bind() on these ports.
          Fix: add "NET_BIND_SERVICE" to hardening.capabilities.add.
        '';
      }
      # -- C2: Custom seccomp JSON makes cross-checks opaque --
      ++
        optional
          (cfg.seccomp.enable && cfg.seccomp.customProfileJson != null && cfg.capabilities.add != [ ])
          {
            assertion = false;
            message = ''
              nix-oci coherence: seccomp.customProfileJson overrides ALL computed
              seccomp rules. Cross-backend coherence with capabilities
              CANNOT be verified — the custom profile may silently contradict them.
              Fix: remove capability overrides when using custom seccomp
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
      }
      # -- P5: AppArmor network rules dead if seccomp blocks network --
      ++
        optional
          (
            cfg.apparmor.enable
            && cfg.apparmor.customProfile == null
            && cfg.seccomp.enable
            && cfg.seccomp.customProfileJson == null
            && !(profileHasNetwork cfg.seccomp.profile)
          )
          {
            assertion = false;
            message = ''
              nix-oci coherence: AppArmor profile includes network rules but
              seccomp profile "${cfg.seccomp.profile}" blocks ALL network syscalls.
              AppArmor network rules have NO EFFECT — seccomp intercepts first.
              Fix: use a network-capable seccomp profile (web-server, database,
              moderate) or disable AppArmor.
            '';
          }
      # -- P6: AppArmor denyPtrace redundant but denyMount/denyUserNamespace
      #    contradicts capability add SYS_ADMIN --
      ++
        optional
          (
            cfg.apparmor.enable
            && cfg.apparmor.customProfile == null
            && (cfg.apparmor.denyMount || cfg.apparmor.denyUserNamespace)
            && elem "SYS_ADMIN" cfg.capabilities.add
          )
          {
            assertion = false;
            message = ''
              nix-oci coherence: AppArmor denies ${
                concatStringsSep " and " (
                  optional cfg.apparmor.denyMount "mount" ++ optional cfg.apparmor.denyUserNamespace "userns"
                )
              }
              but capabilities.add includes SYS_ADMIN which grants these operations.
              The AppArmor deny rules will block what the capability allows —
              this is contradictory configuration.
              Fix: remove SYS_ADMIN from capabilities.add (AppArmor + seccomp
              already block these), or disable the AppArmor deny rules if you
              genuinely need SYS_ADMIN.
            '';
          }
      # -- C3: AppArmor custom profile makes computed rules opaque --
      ++
        optional
          (
            cfg.apparmor.enable
            && cfg.apparmor.customProfile != null
            && (cfg.apparmor.denyUserNamespace || cfg.apparmor.denyMount || cfg.apparmor.denyPtrace)
          )
          {
            assertion = false;
            message = ''
              nix-oci coherence: apparmor.customProfile overrides ALL computed
              AppArmor rules, but deny options are also set
              (${
                concatStringsSep ", " (
                  optional cfg.apparmor.denyUserNamespace "denyUserNamespace"
                  ++ optional cfg.apparmor.denyMount "denyMount"
                  ++ optional cfg.apparmor.denyPtrace "denyPtrace"
                )
              }).
              These deny options have NO EFFECT when a custom profile is used.
              Fix: remove the deny options (custom profile is authoritative),
              or remove the custom profile to use computed rules.
            '';
          }
      # -- D1: AppArmor dead under the podman backend --
      #
      # nixpkgs' pkgs.podman is built without the Go "apparmor" build tag:
      # containers/common's apparmor.IsEnabled() is gated by
      # `//go:build linux && apparmor`, with a `//go:build !linux ||
      # !apparmor` stub that unconditionally returns false wired in instead.
      # Confirmed by reading podman's own vendored source and by a live VM
      # boot: the kernel LSM, apparmor_parser, and the generated profile all
      # load correctly (profile shows up in /sys/kernel/security/apparmor
      # /profiles in enforce mode), but podman still refuses to start the
      # container with "apparmor profile ... specified, but Apparmor is not
      # enabled on this system" -- the host-side config is irrelevant, the
      # binary itself cannot see it. This makes the option a silent no-op
      # (zero enforcement, false sense of security) rather than a build
      # failure, which is worse than refusing outright.
      #
      # `backend` is only known in deploy contexts (threaded via
      # containers.nix's specialArgs -> nixos-config.nix ->
      # evalContainerNixos -> _module.args.backend); it is null for
      # flake-side build-only containers, where no backend is selected yet
      # and this check does not apply.
      ++ optional (cfg.apparmor.enable && backend == "podman") {
        assertion = false;
        message = ''
          nix-oci coherence: hardening.apparmor.enable = true but the
          deploy backend is "podman". nixpkgs' podman package is built
          without AppArmor support (no "apparmor" Go build tag), so
          podman's apparmor.IsEnabled() always returns false regardless
          of the host's actual AppArmor state. The container will fail
          to start with "Apparmor is not enabled on this system", or if
          no profile were attached, would silently run completely
          unconfined -- either way this option provides zero real
          enforcement under podman.
          Fix: set hardening.apparmor.enable = false (rely on seccomp +
          capabilities instead), or switch to backend = "docker", which
          has working AppArmor support (requires a small
          /sbin/apparmor_parser compatibility shim on NixOS).
        '';
      };

    # =====================================================================
    #  WARNINGS — soft trace, build succeeds
    # =====================================================================
    warnings =
      # -- D2: Capabilities add without drop --
      optional (cfg.capabilities.add != [ ] && cfg.capabilities.drop == [ ]) ''
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
      # -- D5: AppArmor complain mode --
      ++ optional (cfg.apparmor.enable && cfg.apparmor.mode == "complain") ''
        nix-oci coherence: apparmor.mode = "complain" — violations are logged
        but NOT BLOCKED. This provides no runtime protection from AppArmor.
        Use mode = "enforce" for production deployments.
      ''
      # -- D6: AppArmor host prerequisite --
      ++ optional cfg.apparmor.enable ''
        nix-oci coherence: AppArmor profile will be generated for this container.
        The target host MUST have AppArmor enabled (kernel LSM + apparmor_parser).
        On NixOS: security.apparmor.enable = true.
        If the host lacks AppArmor, the container will fail to start or fall back
        to unconfined mode depending on the runtime.
      ''
      # -- D4: readOnlyRootfs disabled with hardening enabled --
      ++ optional (!cfg.readOnlyRootfs) ''
        nix-oci coherence: hardening.enable = true but readOnlyRootfs = false.
        Attackers with initial access can write malware or achieve persistence
        on the container filesystem.
        Consider: readOnlyRootfs = true (default) with explicit writable mounts.
      ''
      # -- G3: All enforcement backends weak or disabled --
      ++
        optional
          (
            (!cfg.seccomp.enable || cfg.seccomp.mode == "audit")
            && (!cfg.apparmor.enable || cfg.apparmor.mode == "complain")
            && cfg.capabilities.drop == [ ]
          )
          ''
            nix-oci coherence: hardening.enable = true but ALL enforcement
            backends are disabled or in audit/complain mode, and no capabilities
            are dropped. No meaningful runtime security restrictions are active.
          '';
  };
}
