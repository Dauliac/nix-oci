# Landlock coherence checks: missing bind ports, healthcheck connect.
{
  lib,
  helpers,
}:
ctx:
let
  inherit (ctx)
    name
    enabled
    containerConfig
    mainService
    detectedPorts
    hcPort
    ;
  h = containerConfig.hardening;

  landlockEnabled = h.enable && h.landlock.enable;
  landlockTcpBind = h.landlock.allowedTcpBind or [ ];
  landlockTcpConnect = h.landlock.allowedTcpConnect or [ ];
  missingBindPorts = builtins.filter (p: !(lib.elem p landlockTcpBind)) detectedPorts;
  missingBindList = lib.concatMapStringsSep ", " toString missingBindPorts;

  missingHealthcheckConnect =
    landlockEnabled
    && hcPort != null
    && !(lib.elem hcPort landlockTcpConnect)
    && !(lib.elem hcPort landlockTcpBind);
in
# Landlock missing bind ports
(
  if enabled && landlockEnabled && missingBindPorts != [ ] then
    throw ''
      Container "${name}": Landlock restricts TCP bind but port(s) ${missingBindList}
      detected from "${mainService}" are not in `hardening.landlock.allowedTcpBind`.
      Fix: add the missing port(s):
        hardening.landlock.allowedTcpBind = [ ${missingBindList} ];
    ''
  else
    ""
)
# Landlock blocks healthcheck connect
+ (
  if enabled && missingHealthcheckConnect then
    builtins.trace ''
      WARNING: Container "${name}": Landlock restricts TCP connect but the healthcheck
      targets port ${toString hcPort} which is not in `hardening.landlock.allowedTcpConnect`.
      The healthcheck will fail at runtime. Fix:
        hardening.landlock.allowedTcpConnect = [ ${toString hcPort} ];
    '' ""
  else
    ""
)
