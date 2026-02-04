# OCI mkPodmanPolicy - Build podman security policy configuration
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkPodmanPolicy = {
        type = lib.types.functionTo lib.types.package;
        description = "Build podman security policy configuration";
        fn =
          { }:
          pkgs.writeTextDir "etc/containers/policy.json" ''
            {
                "default": [
                    {
                        "type": "insecureAcceptAnything"
                    }
                ]
            }
          '';
      };
    };
}
