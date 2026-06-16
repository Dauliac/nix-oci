# Privilege escalation auditing functions (linPEAS)
#
# Uses mkProbeToolBundle with needsShell=true — busybox is injected
# automatically as the shell interpreter.
import ../../../../lib/mkLibModule.nix (
  { lib, ociLib, ... }:
  let
    mkBundle = import ../../lib/_mkProbeToolBundle.nix { inherit lib; };
    thisFile = "nix/modules/oci/_testing/linpeas/lib.nix";
    bundle = mkBundle {
      toolId = "linpeas";
      file = thisFile;
      description = "linPEAS privilege escalation auditing";
      probePath = psc: "${psc.packages.linpeas}/bin/linpeas.sh";
      needsShell = true;
      args = "-q -s -N";
      failPatterns = [
        {
          pattern = "docker.sock\\|docker\\.socket";
          message = "Docker socket accessible inside container";
        }
      ];
      warnPatterns = [
        {
          pattern = "You are root";
          message = "Container process runs as root";
        }
      ];
      hermeticFailPatterns = [
        {
          pattern = "docker.sock\\|docker\\.socket";
          message = "Docker socket accessible";
        }
      ];
    } ociLib;
  in
  {
    mkScriptLinpeas = bundle.mkScript;
    mkAppLinpeas = bundle.mkApp;
    mkCheckLinpeas = bundle.mkCheck;
  }
)
