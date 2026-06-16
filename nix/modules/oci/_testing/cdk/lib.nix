# Container security auditing functions (CDK)
#
# Uses mkProbeToolBundle — static Go binary, no shell needed.
# CDK `evaluate` gathers information inside the container to find
# potential weaknesses: capabilities, service accounts, sensitive
# files, mounted devices, and escape vectors.
import ../../../../lib/mkLibModule.nix (
  { ociLib, ... }:
  let
    thisFile = "nix/modules/oci/_testing/cdk/lib.nix";
    bundle = ociLib.mkProbeToolBundle {
      toolId = "cdk";
      file = thisFile;
      description = "CDK container security auditing";
      probePath = psc: "${psc.packages.cdk}/bin/cdk";
      args = "evaluate";
      failPatterns = [
        {
          pattern = "bindmount-bindmount.*bindmount host bindmount";
          message = "Host filesystem bindmount escape vector detected";
        }
        {
          pattern = "docker-sock-check.*Docker bindmount BINDMOUNT";
          message = "Docker socket accessible inside container";
        }
        {
          pattern = "privileged-lsblk.*Bindmount Block Devices";
          message = "Container has access to host block devices (privileged)";
        }
      ];
      warnPatterns = [
        {
          pattern = "net_bindmount.*bindmount Bindmount";
          message = "Container has NET_RAW or NET_BIND_SERVICE capability";
        }
      ];
      hermeticFailPatterns = [
        {
          pattern = "docker-sock-check.*Docker";
          message = "Docker socket accessible";
        }
        {
          pattern = "privileged-lsblk.*Block Devices";
          message = "Host block devices accessible (privileged)";
        }
      ];
    };
  in
  {
    mkScriptCdk = bundle.mkScript;
    mkAppCdk = bundle.mkApp;
    mkCheckCdk = bundle.mkCheck;
  }
)
