# Entrypoint coherence checks: package conflict, forking service, empty entrypoint.
{ lib, helpers }:
ctx:
let
  inherit (ctx)
    name
    enabled
    containerConfig
    evalOutput
    mainService
    ;
  out = evalOutput;
  servicePackage = out.servicePackage or null;
  serviceType =
    if out.serviceData or null != null then out.serviceData.serviceType or "simple" else "simple";

  packageConflict =
    enabled
    && mainService != null
    && containerConfig.package != null
    && servicePackage != null
    && containerConfig.package != servicePackage;
  isForkingService = enabled && mainService != null && serviceType == "forking";
  emptyEntrypoint =
    enabled
    && mainService == null
    && containerConfig.package == null
    && (containerConfig.entrypoint or [ ]) == [ ];
in
# Package conflict
(
  if packageConflict then
    throw ''
      Container "${name}": cannot set both `package` and `nixosConfig.mainService`.
      - To let the NixOS service provide the package: remove `package`, set `mainService`.
      - To control the package yourself: remove `mainService`, set `package` explicitly.
    ''
  else
    ""
)
# Forking service type warning
+ (
  if isForkingService then
    builtins.trace ''
      WARNING: Container "${name}": service "${mainService}" uses Type="forking".
      The process will daemonize and the container may exit immediately.
    '' ""
  else
    ""
)
# Empty entrypoint
+ (
  if emptyEntrypoint then
    throw ''
      Container "${name}": no entrypoint defined. The container has no way to start.
      None of the following are set:
        - `package` (with meta.mainProgram)
        - `nixosConfig.mainService` (auto-derives entrypoint from NixOS service)
        - `entrypoint` (explicit command list)
      Fix: set at least one of these options.
    ''
  else
    ""
)
