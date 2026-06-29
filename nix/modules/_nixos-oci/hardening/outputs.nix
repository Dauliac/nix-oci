{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container.hardening;

  # -- Seccomp constants --

  # Bitmask of CLONE_NEW* flags that create namespaces.
  # clone/clone3 with any of these set = namespace creation = privilege escalation.
  #   CLONE_NEWNS      0x00020000
  #   CLONE_NEWCGROUP  0x02000000
  #   CLONE_NEWUTS     0x04000000
  #   CLONE_NEWIPC     0x08000000
  #   CLONE_NEWUSER    0x10000000
  #   CLONE_NEWPID     0x20000000
  #   CLONE_NEWNET     0x40000000
  #   CLONE_NEWTIME    0x00000080
  cloneNewNamespaceMask = 2114060416; # 0x7E020080

  # ioctl commands for terminal injection attacks.
  ioctlTIOCSTI = 21522; # 0x5412 — inject chars into terminal input
  ioctlTIOCLINUX = 21532; # 0x541C — similar injection vector

  # Socket address families to block.
  afNETLINK = 16; # kernel config manipulation
  afPACKET = 17; # raw packet sniffing

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
    # io_uring bypasses ALL syscall-based security monitoring (Falco, CrowdStrike,
    # Tetragon). Docker 4.42+ blocks these by default. Google restricts internally.
    "io_uring_setup"
    "io_uring_enter"
    "io_uring_register"
    "ioperm"
    "iopl"
    "kcmp"
    "kexec_file_load"
    "kexec_load"
    "keyctl"
    "lookup_dcookie"
    "mbind"
    # memfd_create enables fileless malware: anonymous memory file → mmap PROT_EXEC
    # → execute payload with no file on disk, evading file-based detection.
    "memfd_create"
    "memfd_secret"
    "mount"
    "move_mount"
    "move_pages"
    "name_to_handle_at"
    "nfsservctl"
    "open_by_handle_at"
    "perf_event_open"
    # personality(ADDR_NO_RANDOMIZE) disables ASLR, aiding exploit development.
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

  # GPU/CUDA-specific syscalls beyond web-server baseline.
  # CUDA runtime uses heavy ioctl for GPU command submission, mmap for GPU
  # memory mapping, and perf_event_open for GPU performance counters.
  gpuComputeSyscalls = [
    "perf_event_open"
    "sched_setaffinity"
    "mbind"
    "set_mempolicy"
    "get_mempolicy"
    "migrate_pages"
  ];

  architectures = [
    "SCMP_ARCH_X86_64"
    "SCMP_ARCH_AARCH64"
  ];

  # -- Argument-level filtering rules --

  # Block clone/clone3 with namespace creation flags (allow threading).
  cloneArgFilter = [
    {
      names = [
        "clone"
        "clone3"
      ];
      action = "SCMP_ACT_ERRNO";
      args = [
        {
          index = 0;
          value = cloneNewNamespaceMask;
          valueTwo = cloneNewNamespaceMask;
          op = "SCMP_CMP_MASKED_EQ";
        }
      ];
    }
  ];

  # Block ioctl TIOCSTI and TIOCLINUX terminal injection commands.
  ioctlArgFilter = [
    {
      names = [ "ioctl" ];
      action = "SCMP_ACT_ERRNO";
      args = [
        {
          index = 1;
          value = ioctlTIOCSTI;
          op = "SCMP_CMP_EQ";
        }
      ];
    }
    {
      names = [ "ioctl" ];
      action = "SCMP_ACT_ERRNO";
      args = [
        {
          index = 1;
          value = ioctlTIOCLINUX;
          op = "SCMP_CMP_EQ";
        }
      ];
    }
  ];

  # Block socket() with AF_NETLINK and AF_PACKET (raw sniffing / kernel config).
  socketArgFilter = [
    {
      names = [ "socket" ];
      action = "SCMP_ACT_ERRNO";
      args = [
        {
          index = 0;
          value = afNETLINK;
          op = "SCMP_CMP_EQ";
        }
      ];
    }
    {
      names = [ "socket" ];
      action = "SCMP_ACT_ERRNO";
      args = [
        {
          index = 0;
          value = afPACKET;
          op = "SCMP_CMP_EQ";
        }
      ];
    }
  ];

  # -- Seccomp profiles --

  mkProfile = defaultAction: syscallRules: {
    inherit defaultAction architectures;
    syscalls = syscallRules;
  };

  seccompProfiles = {
    strict = mkProfile "SCMP_ACT_ERRNO" (
      [
        {
          names = lib.unique (baseSyscalls ++ fileIoSyscalls ++ eventLoopSyscalls);
          action = "SCMP_ACT_ALLOW";
        }
      ]
      ++ ioctlArgFilter
    );
    web-server = mkProfile "SCMP_ACT_ERRNO" (
      [
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
      ]
      ++ cloneArgFilter
      ++ socketArgFilter
      ++ ioctlArgFilter
    );
    database = mkProfile "SCMP_ACT_ERRNO" (
      [
        {
          names = lib.unique (
            baseSyscalls
            ++ fileIoSyscalls
            ++ eventLoopSyscalls
            ++ networkSyscalls
            ++ threadingSyscalls
            ++ fsWriteSyscalls
            ++ [
              # Database-specific: memory locking, file management
              "fadvise64"
              "sync_file_range"
              "fdatasync"
              "msync"
              "mincore"
              "getgroups"
              "umask"
            ]
          );
          action = "SCMP_ACT_ALLOW";
        }
      ]
      ++ cloneArgFilter
      ++ socketArgFilter
      ++ ioctlArgFilter
    );
    gpu-compute = mkProfile "SCMP_ACT_ERRNO" (
      [
        {
          names = lib.unique (
            baseSyscalls
            ++ fileIoSyscalls
            ++ eventLoopSyscalls
            ++ networkSyscalls
            ++ threadingSyscalls
            ++ fsWriteSyscalls
            ++ gpuComputeSyscalls
            ++ [
              # CUDA memory management needs these (normally in dangerousSyscalls).
              "memfd_create"
            ]
          );
          action = "SCMP_ACT_ALLOW";
        }
      ]
      ++ cloneArgFilter
      ++ socketArgFilter
      # Note: no ioctl arg filter -- CUDA uses many ioctl commands for GPU
      # command submission that we cannot enumerate. Terminal injection
      # (TIOCSTI/TIOCLINUX) risk is low in headless GPU compute containers.
    );
    moderate = mkProfile "SCMP_ACT_ALLOW" (
      [
        {
          names = dangerousSyscalls;
          action = "SCMP_ACT_ERRNO";
        }
      ]
      ++ cloneArgFilter
      ++ socketArgFilter
      ++ ioctlArgFilter
    );
  };
in
{
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
            let
              profile = seccompProfiles.${cfg.seccomp.profile};
              # In audit mode, replace SCMP_ACT_ERRNO with SCMP_ACT_LOG so
              # disallowed syscalls are logged but not blocked.
              effectiveProfile =
                if cfg.seccomp.mode == "audit" then
                  profile
                  // {
                    defaultAction =
                      if profile.defaultAction == "SCMP_ACT_ERRNO" then "SCMP_ACT_LOG" else profile.defaultAction;
                    syscalls = map (
                      rule: if rule.action == "SCMP_ACT_ERRNO" then rule // { action = "SCMP_ACT_LOG"; } else rule
                    ) profile.syscalls;
                  }
                else
                  profile;
            in
            pkgs.writeText "seccomp.json" (builtins.toJSON effectiveProfile)
        else
          null;
    };

    apparmorProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      internal = true;
      readOnly = true;
      description = "Generated AppArmor profile, or null.";
      default =
        let
          aa = cfg.apparmor;
          containerName = config.oci.container.name or "container";
          profileName = "nix-oci-${containerName}";

          flags =
            if aa.mode == "complain" then
              "(attach_disconnected,mediate_deleted,complain)"
            else
              "(attach_disconnected,mediate_deleted)";

          # Build profile rules from options.
          rules = lib.concatStringsSep "\n  " (
            # Base abstractions
            [ "#include <abstractions/base>" ]
            # Deny user namespace creation (LPE mitigation).
            ++ lib.optional aa.denyUserNamespace "deny userns_create,"
            # Deny mount operations.
            ++ lib.optional aa.denyMount "deny mount,"
            # Deny ptrace.
            ++ lib.optional aa.denyPtrace "deny ptrace (read read trace traceby),"
            # Default: deny raw network access.
            ++ [
              "deny network raw,"
              "deny network packet,"
            ]
            # Allow file access for the Nix store (read + execute).
            ++ [
              "/nix/store/** mr,"
              "/nix/store/*/bin/** ix,"
            ]
            # Standard container paths.
            ++ [
              "/dev/null rw,"
              "/dev/zero r,"
              "/dev/urandom r,"
              "/dev/random r,"
              "/dev/fd/** rw,"
              "/proc/** r,"
              "/sys/fs/cgroup/** r,"
              "/tmp/** rw,"
              "/run/** rw,"
            ]
            # Allow network (TCP/UDP) — fine-grained port control is
            # AppArmor provides the coarse allow; fine-grained port control
            # is handled by seccomp argument filters where applicable.
            ++ [
              "network tcp,"
              "network udp,"
              "network unix,"
            ]
            # Signal self.
            ++ [ "signal (send receive) peer=${profileName}," ]
          );

          profileContent = ''
            #include <tunables/global>

            profile ${profileName} flags=${flags} {
              ${rules}
            }
          '';
        in
        if cfg.enable && aa.enable then
          if aa.customProfile != null then
            aa.customProfile
          else
            pkgs.writeText "${profileName}.apparmor" profileContent
        else
          null;
    };
  };
}
