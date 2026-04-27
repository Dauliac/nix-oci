# OCI mkNixOCI - Build a container with Nix support and build users
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
    in
    {
      nix-lib.lib.oci.mkNixOCI = {
        type = lib.types.functionTo lib.types.package;
        description = "Build a container with Nix support and build users";
        fn =
          args@{
            perSystemConfig,
            containerId,
          }:
          let
            oci = perSystemConfig.containers.${containerId};
            fullName =
              if oci.registry != null && oci.registry != "" then "${oci.registry}/${oci.name}" else oci.name;
          in
          perSystemConfig.packages.nix2container.buildImage {
            inherit (oci) tag;
            name = fullName;
            initializeNixDatabase = true;
            copyToRoot = oci.configFiles or [];
            layers = [
              (ociLib.mkNixOCILayer {
                inherit perSystemConfig;
              })
            ];
            config = {
              inherit (oci) entrypoint;
              Env = [
                "PATH=/bin:/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin"
                "LANG=C.UTF-8"
                "LC_ALL=C.UTF-8"
                "NIX_PAGER=cat"
                "USER=${oci.user}"
                "HOME=/"
              ];
            };
          };
      };
    };
}
