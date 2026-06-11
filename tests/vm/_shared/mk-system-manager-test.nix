# Create a system-manager VM test on Debian 13 via nix-vm-test.
#
# Handles all boilerplate: system-manager register+activate, podman/curl
# symlinks, /etc/containers config, host store mounting.
# Callers only provide container definitions and a Python test body.
{
  inputs,
  config,
  pkgs,
  lib,
  system,
}:
{
  name,
  containers,
  testBody,
  extraSystemManagerModules ? [ ],
}:
let
  systemManagerModule = config.flake.modules.systemManager.nix-oci;
  systemManagerPkg = inputs.system-manager.packages.${system}.default;
  nixBinPath = "${lib.getBin pkgs.nix}/bin";
  podmanPkg = pkgs.podman;
  curlPkg = pkgs.curl;

  systemConfig = inputs.system-manager.lib.makeSystemConfig {
    modules = [
      systemManagerModule
      (
        { pkgs, ... }:
        {
          nixpkgs.hostPlatform = system;

          oci = {
            enable = true;
            backend = "podman";
            inherit containers;
          };

          environment.etc = {
            "containers/policy.json".text = builtins.toJSON {
              default = [ { type = "insecureAcceptAnything"; } ];
            };
            "containers/storage.conf".text = ''
              [storage]
              driver = "overlay"
              runroot = "/run/containers/storage"
              graphroot = "/var/lib/containers/storage"
            '';
            "containers/registries.conf".text = ''
              [registries.search]
              registries = []
            '';
          };
        }
      )
    ]
    ++ extraSystemManagerModules;
  };

  vmTest = inputs.nix-vm-test.lib.${system}.debian."13" {
    memorySize = 2048;
    cpus = 4;
    diskSize = "+2G";

    extraPathsToRegister = [
      systemConfig
      systemManagerPkg
    ];

    testScript = ''
      # Boot
      vm.wait_for_unit("multi-user.target")

      # Symlink Nix-built tools into /usr/local/bin (in default PATH)
      vm.succeed("ln -sf ${podmanPkg}/bin/podman /usr/local/bin/podman")
      vm.succeed("ln -sf ${curlPkg}/bin/curl /usr/local/bin/curl")

      # Apply system-manager config
      vm.succeed(
          "NIX_REMOTE= "
          "PATH=${nixBinPath}:$PATH "
          "${systemManagerPkg}/bin/system-manager register "
          "--store-path ${systemConfig}"
      )
      vm.succeed(
          "${systemManagerPkg}/bin/system-manager activate "
          "--store-path ${systemConfig}"
      )

      ${testBody}
    '';
  };
in
vmTest.sandboxed
