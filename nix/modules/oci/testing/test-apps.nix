# Test flake apps by running them as systemd services in a NixOS VM.
#
# App scripts are self-contained (they use skopeo to load images directly),
# so this VM only needs podman — no oci.containers deploy is required.
#
# Architecture:
# - test-apps.nix (this file): picks apps, builds VM check
# - _test/_apps-config.nix (NixOS module): converts app scripts → systemd oneshots
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci or null;
  nixosTestModule = config.flake.modules.nixos.nix-oci-test or null;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { ... }:
    {
      options.test.oci._bddAppsCheck = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        internal = true;
        description = "Aggregate BDD apps test derivation (all containers in one VM). Kept as a compatibility alias; the parallelizable variant lives in _bddAppsChecks.";
      };
      options.test.oci._bddAppsChecks = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        default = { };
        internal = true;
        description = ''
          Per-container BDD apps test derivations (one VM per container).
          Consumed by tests/flake.nix as `checks.<system>.bdd-app-<containerId>`
          so Nix's build scheduler parallelizes them via --max-jobs, instead of
          serializing every image load inside a single monolithic VM.
        '';
      };
    }
  );

  config.perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      testHelpers = import ../../../../tests/lib.nix { inherit pkgs lib; };
      canBuildTest = nixosModule != null && nixosTestModule != null && pkgs.stdenv.isLinux;

      # Use flake apps, but skip:
      #   * `oci-push-*`  -- pushes to a remote registry via skopeo
      #     docker://...; the in-VM docker-registry serves plain HTTP
      #     and skopeo defaults to HTTPS, aborting with:
      #       http: server gave HTTP response to HTTPS client
      #     The BDD VM's `test_registry_push_pipeline` already covers
      #     the push path end-to-end (via `skopeo --dest-tls-verify=false`
      #     in test-vm.nix's dedicated flake-oci-load service).
      #   * `oci-sandbox-*` -- runs the container entrypoint under
      #     bubblewrap. bwrap chdir's into the image's `WorkingDir`,
      #     which for services like caddy is `/var/lib/caddy` -- a
      #     runtime-only path that does not exist in the sandbox
      #     rootfs. The sandbox path is a separate integration surface
      #     from the load-*/push-* smoke tests this VM is meant to
      #     exercise; giving it a real home would require its own
      #     scaffolding.
      #   * `oci-load-docker-*` -- pushes into `docker-daemon:` via
      #     skopeo. On this VM the docker daemon is actually podman's
      #     docker-compatible socket (dockerSocket.enable=true; there
      #     is no dockerd). Podman's docker-API import path is
      #     dramatically slower than native `containers-storage:`
      #     writes: even a busybox-based hardened image consumes
      #     ~1.4 GB RSS and takes >15 min to import through the
      #     compat socket, tripping `TimeoutStartSec` and failing
      #     the whole VM. `oci-load-podman-*` exercises the same
      #     "does this image load into a runtime" invariant against
      #     the real backend, in seconds. On a docker-backend VM the
      #     load-docker path is exercised in the bdd-vm test's
      #     dedicated flake-oci-load service, so we lose no coverage.
      baseApps = lib.filterAttrs (
        n: _:
        !(lib.hasPrefix "oci-push-" n)
        && !(lib.hasPrefix "oci-sandbox-" n)
        && !(lib.hasPrefix "oci-load-docker-" n)
      ) (config.oci.flake.apps or { });

      # ── Container-probe apps (amicontained / CDK / DEEPCE / linPEAS)
      # Registered pipeline steps stay in the gate derivation; they do
      # NOT surface as flake apps by default. For the VM smoke run we
      # want each opted-in probe to run through the same
      # nix-oci-app-* systemd oneshot machinery as the other apps, so
      # we synthesize apps here from the same mkApp* library functions.
      ociLib = config.lib.oci or { };
      containersByName = config.oci.containers or { };
      # Guard: only build probe apps when the ociLib functions are
      # available AND the container has enabled the probe. `perSystemConfig`
      # here is the current perSystem `config`.
      mkProbeAppsFor =
        probeName: mkFn: enabledPath:
        lib.optionalAttrs (mkFn != null) (
          lib.listToAttrs (
            lib.concatMap (
              containerId:
              let
                cc = containersByName.${containerId};
                isOn = lib.attrByPath enabledPath false cc;
              in
              if isOn then
                [
                  {
                    name = "oci-${probeName}-${containerId}";
                    value = mkFn {
                      perSystemConfig = config;
                      inherit containerId;
                    };
                  }
                ]
              else
                [ ]
            ) (lib.attrNames containersByName)
          )
        );
      probeApps =
        (mkProbeAppsFor "amicontained" (ociLib.mkAppAmicontained or null) [
          "test"
          "amicontained"
          "enabled"
        ])
        // (mkProbeAppsFor "cdk" (ociLib.mkAppCdk or null) [
          "test"
          "cdk"
          "enabled"
        ])
        // (mkProbeAppsFor "deepce" (ociLib.mkAppDeepce or null) [
          "test"
          "deepce"
          "enabled"
        ])
        // (mkProbeAppsFor "linpeas" (ociLib.mkAppLinpeas or null) [
          "test"
          "linpeas"
          "enabled"
        ]);

      allApps = baseApps // probeApps;
      hasApps = allApps != { };

      containerNames = lib.attrNames containersByName;
      hasContainers = containerNames != [ ];

      # Group apps by container. An app named `oci-<verb>-<containerId>` or
      # `oci-<verb>-<backend>-<containerId>` belongs to `containerId`. Suffix
      # match on `-${containerId}` is reliable: per-container app generators
      # (nix/modules/oci/pipeline/compose.nix and the probe generators above)
      # all emit `<prefix>-<containerId>`.
      appsForContainer =
        containerId: lib.filterAttrs (name: _: lib.hasSuffix "-${containerId}" name) allApps;

      # Shared node builder, parameterized on the app subset.
      mkAppsNode =
        apps:
        { ... }:
        {
          imports = [
            nixosModule
            nixosTestModule
          ];

          testing = {
            enable = true;
            appScripts = apps;
          };

          oci = {
            enable = true;
            backend = "podman";
          };
        };

      mkAppsTestScript = apps: ''
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("podman.socket")

        ${lib.concatMapStringsSep "\n" (name: ''
          with subtest("${name}"):
              machine.succeed("systemctl start nix-oci-app-${name}.service")
        '') (lib.attrNames apps)}
      '';

      # Per-container VM checks. One VM per container, each carrying only
      # its own load/probe apps. Nix's --max-jobs runs them in parallel; a
      # stuck load only wedges one VM, not the whole 20-container run.
      perContainerChecks =
        if !(canBuildTest && hasApps && hasContainers) then
          { }
        else
          lib.filterAttrs (_: v: v != null) (
            lib.listToAttrs (
              map (
                containerId:
                let
                  apps = appsForContainer containerId;
                in
                {
                  name = containerId;
                  value =
                    if apps == { } then
                      null
                    else
                      testHelpers.mkVMTest {
                        name = "nix-oci-app-${containerId}";
                        nodes.machine = mkAppsNode apps;
                        testScript = mkAppsTestScript apps;
                      };
                }
              ) containerNames
            )
          );
    in
    {
      # Legacy aggregate: one VM runs every app sequentially. Retained so
      # existing consumers of `_bddAppsCheck` (and `checks.<sys>.bdd-apps`)
      # keep working. Prefer `_bddAppsChecks` for parallel execution.
      test.oci._bddAppsCheck = lib.mkIf (canBuildTest && hasApps && hasContainers) (
        testHelpers.mkVMTest {
          name = "nix-oci-app-tests";
          nodes.machine = mkAppsNode allApps;
          testScript = mkAppsTestScript allApps;
        }
      );

      # New per-container attrset, wired by tests/flake.nix into
      # `checks.<sys>.bdd-app-<containerId>`.
      test.oci._bddAppsChecks = perContainerChecks;
    };
}
