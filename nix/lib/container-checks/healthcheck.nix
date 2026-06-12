# Healthcheck coherence checks: TLS, DNS, port coverage.
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
    allPorts
    healthCmd
    hcPort
    ;
  h = containerConfig.hardening;
  healthCmdStr = lib.concatStringsSep " " healthCmd;
in
# TLS trust store removed + HTTPS healthcheck
(
  if
    enabled
    && (h.noTlsTrustStore or false)
    && helpers.healthcheckHasHttps healthCmd
    && !(helpers.healthcheckHasInsecureFlag healthCmd)
  then
    throw ''
      Container "${name}": `hardening.noTlsTrustStore = true` removes TLS certificates
      but the healthcheck uses HTTPS: ${healthCmdStr}
      Fix with one of:
        - Set `hardening.noTlsTrustStore = false`
        - Switch healthcheck to HTTP
        - Add `-k` to the healthcheck command to skip certificate validation
    ''
  else
    ""
)
# DNS disabled + healthcheck uses hostname
+ (
  if enabled && (h.disableDns or false) && helpers.healthcheckUsesHostname healthCmd then
    builtins.trace ''
      WARNING: Container "${name}": `hardening.disableDns = true` but the healthcheck
      references a hostname: ${healthCmdStr}
      DNS resolution will fail. Use an IP address (127.0.0.1) instead.
    '' ""
  else
    ""
)
# Healthcheck port not in declared/detected ports
+ (
  if enabled && hcPort != null && allPorts != [ ] && !(lib.elem hcPort allPorts) then
    builtins.trace ''
      WARNING: Container "${name}": healthcheck targets port ${toString hcPort} but this
      port is not in the container's declared or detected ports: ${
        lib.concatMapStringsSep ", " toString allPorts
      }.
      This may indicate the healthcheck is checking an unreachable endpoint.
      Fix: add "${toString hcPort}" to `ports` or verify the healthcheck URL.
    '' ""
  else
    ""
)
