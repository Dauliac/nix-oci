# Port validation checks: format, privileged ports, duplicates.
{ lib, helpers }:
ctx:
let
  inherit (ctx)
    name
    enabled
    containerConfig
    ;
  h = containerConfig.hardening;
  capsAdd = h.capabilities.add or [ ];
  capsDrop = h.capabilities.drop or [ ];
  hasNetBindService = lib.elem "NET_BIND_SERVICE" capsAdd;
  dropsAll = lib.elem "ALL" capsDrop;

  invalidPorts = builtins.filter (p: !(helpers.isValidPortSpec p)) (containerConfig.ports or [ ]);

  privilegedPorts = helpers.extractPrivilegedPorts ctx.allPorts;
  hasPrivilegedPorts = privilegedPorts != [ ];
  portList = lib.concatMapStringsSep ", " toString privilegedPorts;

  privilegedPortViolation =
    enabled && h.enable && !containerConfig.isRoot && hasPrivilegedPorts && !hasNetBindService;
  rootDroppedBindViolation =
    enabled
    && h.enable
    && containerConfig.isRoot
    && hasPrivilegedPorts
    && dropsAll
    && !hasNetBindService;

  hostPorts = builtins.filter (p: p != null) (map helpers.parseHostPort (containerConfig.ports or [ ]));
  uniqueHostPorts = lib.unique hostPorts;
  duplicateHostPorts = builtins.filter (p: lib.count (x: x == p) hostPorts > 1) uniqueHostPorts;
in
# Invalid port format
(
  if invalidPorts != [ ] then
    throw ''
      Container "${name}": invalid port mapping format: ${
        lib.concatStringsSep ", " (map (p: ''"${p}"'') invalidPorts)
      }.
      Expected format: "hostPort:containerPort" or "hostPort:containerPort/proto"
      where proto is "tcp" or "udp".
      Examples: "8080:8080", "443:443/tcp", "5353:53/udp"
    ''
  else
    ""
)
# Privileged port + non-root
+ (
  if privilegedPortViolation then
    throw ''
      Container "${name}": non-root user cannot bind privileged port(s): ${portList}.
      Fix with one of:
        - Set `isRoot = true`
        - Use a port >= 1024 (e.g. services.nginx.defaultHTTPListenPort = 8080)
        - Add `hardening.capabilities.add = [ "NET_BIND_SERVICE" ]`
    ''
  else
    ""
)
# Privileged port + dropped caps
+ (
  if rootDroppedBindViolation then
    throw ''
      Container "${name}": capabilities drop ALL but port(s) ${portList} require NET_BIND_SERVICE.
      Fix with one of:
        - Add `hardening.capabilities.add = [ "NET_BIND_SERVICE" ]`
        - Use a port >= 1024 (e.g. services.nginx.defaultHTTPListenPort = 8080)
    ''
  else
    ""
)
# Duplicate host port mappings
+ (
  if duplicateHostPorts != [ ] then
    throw ''
      Container "${name}": duplicate host port(s): ${
        lib.concatMapStringsSep ", " toString duplicateHostPorts
      }.
      Each host port can only be bound once. Multiple containers or mappings
      using the same host port will fail at runtime.
      Fix: use unique host ports for each mapping.
    ''
  else
    ""
)
