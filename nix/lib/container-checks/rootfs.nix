# Read-only rootfs checks: writable directories not covered by volumes.
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
    evalOutput
    ;
  h = containerConfig.hardening;
  out = evalOutput;
  serviceData = out.serviceData or null;
  wDirs = helpers.writableDirs serviceData;
  declaredVolumes = out.declaredVolumes or [ ];
  uncoveredWriteDirs = builtins.filter (d: !(lib.elem d declaredVolumes) && d != "/tmp") wDirs;
  uncoveredDirList = lib.concatMapStringsSep ", " (d: "\"${d}\"") uncoveredWriteDirs;
in
if enabled && (h.readOnlyRootfs or false) && uncoveredWriteDirs != [ ] then
  builtins.trace ''
    WARNING: Container "${name}": `hardening.readOnlyRootfs = true` but the service
    writes to directories not covered by declared volumes: ${uncoveredDirList}.
    These writes will fail at runtime. Fix with one of:
      - Add them to `declaredVolumes`
      - Mount them as tmpfs via deploy config
  '' ""
else
  ""
