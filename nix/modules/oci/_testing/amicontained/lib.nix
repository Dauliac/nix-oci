# Container introspection functions (amicontained)
#
# Uses mkProbeToolBundle — static binary, no shell needed.
import ../../../../lib/mkLibModule.nix (
  { ociLib, ... }:
  let
    thisFile = "nix/modules/oci/_testing/amicontained/lib.nix";
    bundle = ociLib.mkProbeToolBundle {
      toolId = "amicontained";
      file = thisFile;
      description = "amicontained container introspection";
      probePath = psc: "${psc.packages.amicontained}/bin/amicontained";
      failPatterns = [
        {
          pattern = "Is Privileged.*true";
          message = "Container is running in privileged mode";
        }
      ];
      warnPatterns = [
        {
          pattern = "Seccomp.*disabled";
          message = "Seccomp is disabled — no syscall filtering";
        }
      ];
    };
  in
  {
    mkScriptAmicontained = bundle.mkScript;
    mkAppAmicontained = bundle.mkApp;
    mkCheckAmicontained = bundle.mkCheck;
  }
)
