# Seccomp coherence checks: strict vs networking, forking, allocator.
{ lib, helpers }:
ctx:
let
  inherit (ctx)
    name
    enabled
    containerConfig
    mainService
    allPorts
    hasPorts
    ;
  h = containerConfig.hardening;

  seccompEnabled = h.enable && h.seccomp.enable;
  seccompProfile = h.seccomp.profile or "moderate";
  isStrictSeccomp = seccompEnabled && seccompProfile == "strict";
  serviceNeedsForking = mainService != null && lib.elem mainService helpers.forkingServices;

  allocatorSeccompConflict =
    enabled && isStrictSeccomp && (containerConfig.performance or { }).allocator or null != null;
in
# Seccomp strict + networking
(
  if enabled && isStrictSeccomp && hasPorts then
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
# Seccomp strict + forking service
+ (
  if enabled && isStrictSeccomp && serviceNeedsForking then
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
# LD_PRELOAD + seccomp strict conflict
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
