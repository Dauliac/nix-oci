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
            optimized = oci.optimizeLayers or false;
          in
          let
            # Application package + dependencies as a buildEnv.
            # Unlike mkSimpleOCI we do NOT use mkRoot here because mkRoot
            # includes its own shadow setup (mkRootShadowSetup) which would
            # overwrite the nixbld users from mkNixOCILayer's mkNixShadowSetup,
            # causing "group 'nixbld' does not exist" errors.
            pkg = if oci.package != null then [ oci.package ] else [ ];
            deps = oci.dependencies or [ ];
            appPaths = if optimized then pkg ++ [ pkgs.cacert ] else pkg ++ deps ++ [ pkgs.cacert ];
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
            depsLayers =
              if optimized && deps != [ ] then
                [
                  (ociLib.mkDepsLayer {
                    inherit perSystemConfig;
                    dependencies = deps;
                  })
                ]
              else
                [ ];
            home = if oci.user == "root" then "/root" else "/home/${oci.user}";
            homeDir = pkgs.runCommand "home-dir" { } ''
              mkdir -p $out${home}
            '';
            # Nix requires /nix/var/nix/profiles to exist and be writable
            # by the container user. For non-root users, pre-create it
            # so `nix eval`/`nix build` don't fail with Permission denied.
            nixVarDirs = pkgs.runCommand "nix-var-dirs" { } ''
              mkdir -p $out/nix/var/nix/profiles/per-user/${oci.user}
              mkdir -p $out/nix/var/nix/gcroots/per-user/${oci.user}
              mkdir -p $out/nix/var/nix/temproots
            '';
            # configFiles must NOT be in the top-level copyToRoot when
            # initializeNixDatabase = true. nix2container registers all
            # copyToRoot closure paths in the Nix DB, but then rewrites
            # them out of /nix/store/ into /etc/... .  This creates a
            # DB-vs-disk inconsistency: the DB says the store path is
            # valid but lstat() fails because the file was moved.
            #
            # Fix: put configFiles in a separate layer with its own
            # copyToRoot. The layer is NOT included in the nixDatabase
            # closure graph, so the rewritten paths are never registered
            # in the DB.
            configFiles = oci.configFiles or [ ];
            configFilesLayer =
              if configFiles != [ ] then
                [
                  (perSystemConfig.packages.nix2container.buildLayer {
                    copyToRoot = configFiles;
                  })
                ]
              else
                [ ];
          in
          perSystemConfig.packages.nix2container.buildImage (
            {
              inherit (oci) tag;
              name = fullName;
              initializeNixDatabase = true;
              # Non-root users need ownership of /nix for single-user mode.
              nixUid = if oci.user == "root" then 0 else 4000;
              nixGid = if oci.user == "root" then 0 else 4000;
              copyToRoot = [
                appPackages
                homeDir
                nixVarDirs
              ];
              # Non-root users need write access to the entire Nix state
              # (/nix/var/nix/ and /nix/store/) for single-user mode.
              # nix2container's perms sets ownership in the OCI layer.
              perms = lib.optionals (oci.user != "root") [
                {
                  path = nixVarDirs;
                  regex = "/nix/var/nix/.*";
                  mode = "0755";
                  uid = 4000;
                  gid = 4000;
                }
              ];
              layers = [
                (ociLib.mkNixOCILayer {
                  inherit perSystemConfig;
                  user = oci.user;
                  inherit home;
                })
              ]
              ++ depsLayers
              ++ configFilesLayer;
              config = {
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
              // lib.optionalAttrs (oci.labels != { }) {
                Labels = oci.labels;
              };
            }
            // lib.optionalAttrs optimized {
              maxLayers = 40;
            }
          );
      };
    };
}
