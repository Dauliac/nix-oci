# OCI mkNixOCI - Build a container with Nix support and build users
{lib, ...}: {
  config.perSystem = {
    pkgs,
    lib,
    config,
    ...
  }: let
    ociLib = config.lib.oci or {};
  in {
    nix-lib.lib.oci.mkNixOCI = {
      type = lib.types.functionTo lib.types.package;
      description = "Build a container with Nix support and build users";
      fn = args @ {
        perSystemConfig,
        containerId,
      }: let
        oci = perSystemConfig.containers.${containerId};
        # Force-evaluate nixosConfig assertions/warnings
        _nixosChecks = oci.nixosConfig._checks or "";
        fullName =
          if oci.registry != null && oci.registry != ""
          then "${oci.registry}/${oci.name}"
          else oci.name;
        optimized = oci.optimizeLayers or false;
        layerStrategy = oci.layerStrategy or "fine-grained";
      in
        assert _nixosChecks == "" || _nixosChecks != ""; let
          pkg =
            if oci.package != null
            then [oci.package]
            else [];
          deps = oci.dependencies or [];
          appPaths =
            if optimized
            then pkg ++ [pkgs.cacert]
            else pkg ++ deps ++ [pkgs.cacert];
          appPackages = pkgs.buildEnv {
            name = "app-root";
            paths = appPaths;
            pathsToLink = [
              "/bin"
              "/lib"
              "/etc"
            ];
            ignoreCollisions = true;
          };
          home =
            if oci.user == "root"
            then "/root"
            else "/home/${oci.user}";
          homeDir = pkgs.runCommand "home-dir" {} ''
            mkdir -p $out${home}
          '';
          nixVarDirs = pkgs.runCommand "nix-var-dirs" {} ''
            mkdir -p $out/nix/var/nix/profiles/per-user/${oci.user}
            mkdir -p $out/nix/var/nix/gcroots/per-user/${oci.user}
            mkdir -p $out/nix/var/nix/temproots
          '';
          configFiles = oci.configFiles or [];

          # The Nix layer (bash, coreutils, nix, shadow setup) is built
          # directly via buildLayer — it's the foundation that everything
          # else deduplicates against.
          nixLayer = ociLib.mkNixOCILayer {
            inherit perSystemConfig;
            user = oci.user;
            inherit home;
          };

          # Config files as a layer-def for the fold chain
          configFilesLayerDefs =
            if configFiles != []
            then [{copyToRoot = configFiles;}]
            else [];

          layers =
            if optimized
            then
              ociLib.mkImageLayers {
                nix2container = perSystemConfig.packages.nix2container;
                inherit layerStrategy;
                # nixLayer is already built — inject as a known layer so
                # the fold deduplicates against its store paths.
                prependBuiltLayers = [nixLayer];
                prependLayerDefs = configFilesLayerDefs;
                dependencies = deps;
                copyToRoot = [
                  appPackages
                  homeDir
                  nixVarDirs
                ];
              }
            else
              [nixLayer]
              ++ (
                if configFiles != []
                then [
                  (perSystemConfig.packages.nix2container.buildLayer {
                    copyToRoot = configFiles;
                  })
                ]
                else []
              );
        in
          perSystemConfig.packages.nix2container.buildImage (
            {
              inherit (oci) tag;
              name = fullName;
              copyToRoot = [
                appPackages
                homeDir
                nixVarDirs
              ];
              perms = lib.optionals (oci.user != "root") [
                {
                  path = nixVarDirs;
                  regex = "/nix/var/nix/.*";
                  mode = "0755";
                  uid = 4000;
                  gid = 4000;
                }
              ];
              inherit layers;
              config =
                {
                  inherit (oci) entrypoint;
                  User = oci.user;
                  Env = [
                    "PATH=/bin:${home}/.nix-profile/bin:/nix/var/nix/profiles/default/bin"
                    "LANG=C.UTF-8"
                    "LC_ALL=C.UTF-8"
                    "NIX_PAGER=cat"
                    "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
                    "USER=${oci.user}"
                    "HOME=${home}"
                  ];
                }
                // lib.optionalAttrs (oci.labels != {}) {
                  Labels = oci.labels;
                };
            }
            // lib.optionalAttrs (optimized && layerStrategy == "fine-grained") {
              maxLayers = 40;
            }
          );
    };
  };
}
