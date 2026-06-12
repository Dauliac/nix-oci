# Capability name validation.
{
  lib,
  helpers,
}:
ctx:
let
  inherit (ctx) name containerConfig;
  h = containerConfig.hardening;
  capsAdd = h.capabilities.add or [ ];
  capsDrop = h.capabilities.drop or [ ];
  allCaps = capsAdd ++ capsDrop;
  invalidCaps = builtins.filter (c: !(lib.elem c helpers.validCapabilities)) allCaps;
in
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
