# OCI mkSeccompProfile - Generate a seccomp profile JSON from hardening config
#
# Provides three predefined profiles using different strategies:
#   - strict:     SCMP_ACT_ERRNO default, allowlist ~60 essential syscalls
#   - moderate:   SCMP_ACT_ALLOW default, blocklist ~44 dangerous syscalls
#   - web-server: SCMP_ACT_ERRNO default, allowlist strict + network + threading
#
# Seccomp operates at the syscall boundary via BPF — it controls *which
# operations* a process can invoke, complementary to Landlock (which
# controls *which resources* are accessible).
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      # -- Syscall groups --
      # Essential process, memory, file, signal syscalls for any binary.
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

      # File I/O syscalls.
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

      # Event loop syscalls (epoll, poll, select).
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

      # Network I/O syscalls.
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

      # Threading and advanced I/O.
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

      # Filesystem write operations.
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

      # Dangerous syscalls that should be blocked.
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

      # -- Composed profiles --

      architectures = [
        "SCMP_ARCH_X86_64"
        "SCMP_ARCH_AARCH64"
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
    {
      nix-lib.lib.oci.mkSeccompProfile = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Generate a seccomp profile JSON file from hardening configuration.

          When `hardening.seccomp.customProfileJson` is set, uses that file
          directly. Otherwise generates a predefined profile from the syscall
          groups defined above.

          Returns a store path to the JSON file, suitable for use with
          `--security-opt seccomp=`.
        '';
        fn =
          {
            name,
            hardening,
          }:
          if hardening.seccomp.customProfileJson != null then
            hardening.seccomp.customProfileJson
          else
            pkgs.writeText "seccomp-${name}.json" (builtins.toJSON profiles.${hardening.seccomp.profile});
      };
    };
}
