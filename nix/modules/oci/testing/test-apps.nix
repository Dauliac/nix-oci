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
  imports = [
    # Dendritic probe registry: one file per container-probe tool
    # contributes its name to `oci.testing.knownProbes`, which this
    # module iterates to synthesise probe apps. _probes/ is _-prefixed
    # so import-tree does NOT auto-discover it; the import below is
    # the single entry point.
    ./_probes
  ];

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

      # ── Container-probe apps (dendritic discovery) ──────────
      # The list of known probe names is contributed by sibling files
      # under _probes/. Each probe name maps mechanically to:
      #   mkAppFn     = ociLib.mkApp${Capitalized name}
      #   enabledPath = [ "test" name "enabled" ]
      # so adding a new probe is a one-file change under _probes/ plus
      # the corresponding lib function and per-container option; no edit
      # to this file. Pipeline steps register separately in the gate
      # derivation; those do NOT surface as flake apps by default.
      ociLib = config.lib.oci or { };
      containersByName = config.oci.containers or { };
      knownProbes = lib.sort (a: b: a < b) (config.oci.testing.knownProbes or [ ]);

      capitalize = s: (lib.toUpper (builtins.substring 0 1 s)) + (builtins.substring 1 (-1) s);

      mkProbeAppsFor =
        probeName:
        let
          mkFn = ociLib."mkApp${capitalize probeName}" or null;
          enabledPath = [
            "test"
            probeName
            "enabled"
          ];
        in
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

      probeApps = lib.foldl' (acc: probeName: acc // (mkProbeAppsFor probeName)) { } knownProbes;

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

      # Default parallel strategy for the per-container smoke VMs.
      # `wantedBy` wires every app oneshot into multi-user.target so
      # systemd runs them concurrently and `wait_for_unit multi-user`
      # blocks until all have reached active (RemainAfterExit). This is
      # the fastest shape when loading many apps in one VM; for a
      # one-app per-container VM it is semantically equivalent to
      # sequential (and still cheaper, no driver round-trips).
      defaultParallelStrategy = "wantedBy";

      # Shared node builder, parameterized on the app subset.
      # Composition: imports the nix-oci + nix-oci-test NixOS modules
      # (needed for `testing.appScripts` + `oci.enable`) alongside the
      # dendritic `_app-vm` module that owns the option surface. Callers
      # (per-container _tests files) can override any sizing / backend /
      # strategy knob via standard module composition:
      #
      #   oci.testing.appVm.resources.memoryMiB = lib.mkOverride 50 3072;
      #   oci.testing.appVm.parallelStrategy = lib.mkForce "sequential";
      #
      # without touching this builder.
      mkAppsNode =
        {
          apps,
          parallelStrategy ? defaultParallelStrategy,
        }:
        { ... }:
        {
          imports = [
            nixosModule
            nixosTestModule
            ./_app-vm
          ];
          oci.testing.appVm = {
            inherit apps parallelStrategy;
          };
        };

      # testScript shape depends on strategy. The `wantedBy` strategy
      # anchors every oneshot to multi-user.target in the systemd unit
      # graph, so a single `wait_for_unit` blocks until every app
      # oneshot has reached active, no Python loop. `sequential` keeps
      # the per-subtest `systemctl start` loop (the historical shape).
      # `no-block` fans out via --no-block then waits in a second pass.
      mkAppsTestScript =
        {
          apps,
          parallelStrategy ? defaultParallelStrategy,
        }:
        if parallelStrategy == "wantedBy" then
          ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("podman.socket")
          ''
        else if parallelStrategy == "no-block" then
          ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("podman.socket")

            ${lib.concatMapStringsSep "\n" (name: ''
              machine.succeed("systemctl start --no-block nix-oci-app-${name}.service")
            '') (lib.attrNames apps)}

            ${lib.concatMapStringsSep "\n" (name: ''
              with subtest("${name}"):
                  machine.wait_for_unit("nix-oci-app-${name}.service")
            '') (lib.attrNames apps)}
          ''
        else
          ''
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
                        nodes.machine = mkAppsNode { inherit apps; };
                        testScript = mkAppsTestScript { inherit apps; };
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
          nodes.machine = mkAppsNode { apps = allApps; };
          testScript = mkAppsTestScript { apps = allApps; };
        }
      );

      # New per-container attrset, wired by tests/flake.nix into
      # `checks.<sys>.bdd-app-<containerId>`.
      test.oci._bddAppsChecks = perContainerChecks;
    };
}
