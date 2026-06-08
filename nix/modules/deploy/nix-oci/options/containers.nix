# oci.containers — registered for NixOS, home-manager, and system-manager.
#
# Submodule imports SHARED option definitions from oci/containers/_options/
# (same source of truth as flake-parts) + deploy-specific extensions from _containers/.
# nix2container and ociLib are threaded into the submodule via specialArgs.
{ import-tree, ... }:
let
  # Shared core options (package, dependencies, isRoot, entrypoint, user, name, tag, etc.)
  sharedOptions = import-tree ../../../oci/containers/_options;
  # Deploy-specific extensions (autoStart, volumes, image, image-ref, _defaults)
  deployExtensions = import-tree ./_containers;

  mkOciLib =
    lib:
    let
      parseContainerPort =
        portSpec:
        let
          parts = lib.splitString ":" portSpec;
          raw = if builtins.length parts >= 2 then builtins.elemAt parts 1 else builtins.head parts;
        in
        if lib.hasInfix "/" raw then raw else "${raw}/tcp";

      mkExposedPorts =
        ports:
        builtins.listToAttrs (map (p: lib.nameValuePair (parseContainerPort p) { }) ports);

      parseHostPort =
        portSpec:
        let
          raw = builtins.head (lib.splitString ":" portSpec);
          clean = builtins.head (lib.splitString "/" raw);
        in
        lib.toInt clean;

      mkShadowSetup =
        {
          isRoot,
          user,
          runtimeShell,
          pkgs,
        }:
        if isRoot then
          [
            (pkgs.writeTextDir "etc/passwd" "root:x:0:0::/root:${runtimeShell}\n")
            (pkgs.writeTextDir "etc/shadow" "root:!x:::::::\n")
            (pkgs.writeTextDir "etc/group" "root:x:0:\n")
          ]
        else
          [
            (pkgs.writeTextDir "etc/passwd" ''
              root:x:0:0::/root:${runtimeShell}
              ${user}:x:4000:4000::/home/${user}:${runtimeShell}
            '')
            (pkgs.writeTextDir "etc/shadow" ''
              root:!x:::::::
              ${user}:!:::::::
            '')
            (pkgs.writeTextDir "etc/group" ''
              root:x:0:
              ${user}:x:4000:
            '')
            (pkgs.runCommand "home-${user}" { } ''
              mkdir -p $out/home/${user}
            '')
          ];

      mkRoot =
        {
          name,
          package,
          dependencies,
          configFiles,
          isRoot,
          user,
          pkgs,
        }:
        pkgs.buildEnv {
          name = "oci-root-${name}";
          paths =
            (lib.optional (package != null) package)
            ++ dependencies
            ++ configFiles
            ++ (mkShadowSetup {
              inherit isRoot user pkgs;
              runtimeShell = pkgs.runtimeShell;
            });
          pathsToLink = [
            "/bin"
            "/lib"
            "/etc"
            "/home"
          ];
          ignoreCollisions = true;
        };
    in
    {
      inherit
        parseContainerPort
        mkExposedPorts
        parseHostPort
        mkShadowSetup
        mkRoot
        ;
    };

  mod =
    {
      lib,
      pkgs,
      nix2container,
      ...
    }:
    let
      ociLib = mkOciLib lib;
    in
    {
      options.oci.containers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submoduleWith {
            modules = [
              sharedOptions
              deployExtensions
            ];
            specialArgs = {
              inherit pkgs nix2container ociLib;
            };
          }
        );
        default = { };
        description = ''
          OCI containers to build, load, and optionally run.
          Each entry builds an image via nix2container and creates
          a systemd service to load it into the container runtime.
        '';
      };
    };
in
{
  flake.modules.nixos.nix-oci-containers = mod;
  flake.modules.homeManager.nix-oci-containers = mod;
  flake.modules.systemManager.nix-oci-containers = mod;
}
