# Container escape detection functions (DEEPCE)
#
# Uses mkProbeToolBundle with needsShell=true — busybox is injected
# automatically as the shell interpreter.
import ../../../../lib/mkLibModule.nix (
  { lib, ociLib, ... }:
  let
    mkBundle = import ../../lib/_mkProbeToolBundle.nix { inherit lib; };
    thisFile = "nix/modules/oci/_testing/deepce/lib.nix";
    bundle = mkBundle {
      toolId = "deepce";
      file = thisFile;
      description = "DEEPCE container escape detection";
      probePath = psc: "${psc.packages.deepce}/bin/deepce.sh";
      needsShell = true;
      args = "--no-network --no-colors";
      failPatterns = [
        {
          pattern = "Docker Socket Found";
          message = "Docker socket is exposed inside the container";
        }
        {
          pattern = "Privileged Mode";
          message = "Container is running in privileged mode";
        }
      ];
      hermeticFailPatterns = [
        {
          pattern = "Docker Socket Found";
          message = "Docker socket exposed";
        }
        {
          pattern = "Privileged Mode";
          message = "Privileged mode detected";
        }
      ];
    } ociLib;
  in
  {
    mkScriptDeepce = bundle.mkScript;
    mkAppDeepce = bundle.mkApp;
    mkCheckDeepce = bundle.mkCheck;
  }
)
