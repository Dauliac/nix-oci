# Container hardening: inner NixOS module contract.
#
# This is the middle layer between nix-oci shared options and the inner
# container NixOS definition. It:
#   1. Defines `oci.container.hardening.*` options (same shape as shared)
#   2. Auto-detects configured services and adjusts hardening defaults
#   3. Overrides NixOS config (nsswitch, resolv, certs) when hardening is on
#   4. Outputs build artifacts via `oci.container._output.hardening.*`
#
# Users can configure hardening through their nixosConfig modules:
#   oci.containers.my-app.nixosConfig.modules = [
#     ({ ... }: { oci.container.hardening.disableDns = true; })
#   ];
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

  # -- Seccomp profile data (same as nix-lib mkSeccompProfile) --

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

  architectures = [
    "SCMP_ARCH_X86_64"
    "SCMP_ARCH_AARCH64"
  ];

  seccompProfiles = {
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
{
  # -- Option definitions (the contract) --

  options.oci.container.hardening = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable container security hardening.";
    };
    disableDns = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable DNS resolution.";
    };
    noTlsTrustStore = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Remove TLS trust store.";
    };
    seccomp = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable seccomp profile.";
          };
          profile = lib.mkOption {
            type = lib.types.enum [
              "strict"
              "moderate"
              "web-server"
            ];
            default = "moderate";
            description = "Seccomp profile level.";
          };
          customProfileJson = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Custom seccomp profile JSON.";
          };
        };
      };
      default = { };
      description = "Seccomp syscall filtering configuration.";
    };
    landlock = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable Landlock LSM restrictions.";
          };
          allowedReadPaths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Filesystem paths allowed for reading.";
          };
          allowedWritePaths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Filesystem paths allowed for writing.";
          };
          allowedExecutePaths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Filesystem paths allowed for execution.";
          };
          allowedTcpConnect = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ ];
            description = "TCP ports allowed for outgoing connections.";
          };
          allowedTcpBind = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ ];
            description = "TCP ports allowed for binding.";
          };
        };
      };
      default = { };
      description = "Landlock LSM access control configuration.";
    };
  };

  # -- Build artifact outputs --

  options.oci.container._output.hardening = {
    seccompProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      internal = true;
      readOnly = true;
      description = "Generated seccomp profile JSON, or null.";
      default =
        if cfg.enable && cfg.seccomp.enable then
          if cfg.seccomp.customProfileJson != null then
            cfg.seccomp.customProfileJson
          else
            pkgs.writeText "seccomp.json" (builtins.toJSON seccompProfiles.${cfg.seccomp.profile})
        else
          null;
    };

    configFiles = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      description = "Hardened /etc config file derivations.";
      default = lib.optionals cfg.enable (
        # NOTE: /etc/resolv.conf is NOT written here -- container runtimes
        # always bind-mount it at startup, masking any image content.
        # DNS restriction is enforced via nsswitch.conf (hosts: files only).
        lib.optionals cfg.noTlsTrustStore [
          (pkgs.writeTextDir "etc/ssl/certs/ca-bundle.crt" "# TLS trust store removed by nix-oci hardening\n")
        ]
      );
    };

    labels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
      readOnly = true;
      description = "OCI labels encoding runtime security hints.";
      default = lib.optionalAttrs cfg.enable {
        "io.github.dauliac.nix-oci.hardening.enabled" = "true";
        "io.github.dauliac.nix-oci.hardening.no-new-privileges" = "true";
        "io.github.dauliac.nix-oci.hardening.read-only-rootfs" = "true";
      };
    };

    landlockPolicy = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      internal = true;
      readOnly = true;
      description = "Generated Landlock policy JSON, or null.";
      default =
        if cfg.enable && cfg.landlock.enable then
          pkgs.writeText "landlock.json" (
            builtins.toJSON {
              version = 1;
              fs = {
                read = cfg.landlock.allowedReadPaths;
                write = cfg.landlock.allowedWritePaths;
                execute = cfg.landlock.allowedExecutePaths;
              };
              net = {
                connectTcp = cfg.landlock.allowedTcpConnect;
                bindTcp = cfg.landlock.allowedTcpBind;
              };
            }
          )
        else
          null;
    };
  };

  # -- NixOS config overrides (service auto-detection) --

  config = lib.mkIf cfg.enable {
    # Auto-default seccomp to web-server when a web server is detected.
    oci.container.hardening.seccomp.profile = lib.mkDefault (
      if hasWebServer then "web-server" else "strict"
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
  };
}
