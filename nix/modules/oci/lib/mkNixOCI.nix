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
          let
            # Application package + dependencies as a buildEnv.
            # Unlike mkSimpleOCI we do NOT use mkRoot here because mkRoot
            # includes its own shadow setup (mkRootShadowSetup) which would
            # overwrite the nixbld users from mkNixOCILayer's mkNixShadowSetup,
            # causing "group 'nixbld' does not exist" errors.
            appPackages = let
              pkg = if oci.package != null then [ oci.package ] else [ ];
              deps = oci.dependencies or [ ];
            in
            pkgs.buildEnv {
              name = "app-root";
              paths = pkg ++ deps;
              pathsToLink = [ "/bin" "/lib" "/etc" ];
              ignoreCollisions = true;
            };
          in
          perSystemConfig.packages.nix2container.buildImage {
            inherit (oci) tag;
            name = fullName;
            initializeNixDatabase = true;
            copyToRoot = [ appPackages ] ++ (oci.configFiles or []);
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
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "USER=${oci.user}"
                "HOME=/"
              ];
            };
          };
      };
    };
}
