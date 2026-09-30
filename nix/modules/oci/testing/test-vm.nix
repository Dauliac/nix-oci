# BDD VM test builder.
#
# The VM runs only runtime/deploy BDD specs and a single registry push
# test. Flake-level example containers are build-time dependencies
# (they must build successfully) but are NOT pushed into the VM —
# this keeps the VM test fast (~2-3 min instead of ~12 min).
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci or null;
  nixosTestModule = config.flake.modules.nixos.nix-oci-test or null;
  pythonGen = import ./_python-gen.nix { inherit lib; };

  extractVmSpecs =
    allSpecs:
    lib.concatMapAttrs (
      group: scenarios:
      lib.concatMapAttrs (
        name: spec:
        if spec.level == "runtime" || spec.level == "deploy" then { "${group}--${name}" = spec; } else { }
      ) scenarios
    ) allSpecs;
in
{
  # Internal options
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    let
      vmSpecs = extractVmSpecs (config.test.oci.perContainer or { });
    in
    {
      options.test.oci._vmContainers = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        internal = true;
        readOnly = true;
        default = lib.mapAttrs (_: spec: spec.container) vmSpecs;
      };

      options.test.oci._vmAssertions = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        internal = true;
        readOnly = true;
        default = lib.mapAttrs (_: spec: {
          inherit (spec) assertions;
          given = spec.given or "";
          "when" = spec."when" or "";
          "then" = spec."then" or "";
        }) vmSpecs;
      };

      options.test.oci._vmBackend = lib.mkOption {
        type = lib.types.enum [
          "podman"
          "docker"
        ];
        default = "podman";
        internal = true;
        description = "Container backend for the test VM.";
      };

      options.test.oci._vmSociEnabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        internal = true;
        description = "Whether SOCI snapshotter verification is enabled in the test VM.";
      };

      options.test.oci._bddVmCheck = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        internal = true;
        description = "BDD VM test derivation (set by test-vm.nix, consumed by e2e gate).";
      };
    }
  );

  # VM check generation
  config.perSystem =
    {
      config,
      pkgs,
      lib,
      system,
      ...
    }:
    let
      testHelpers = import ../../../../tests/lib.nix { inherit pkgs lib; };
      ociLib = config.lib.oci or { };
      # Prefer turbo skopeo (layer cache + SOCI indexes) when available,
      # fall back to regular nix2container skopeo.
      skopeoNix2container = config.oci.packages.skopeoTurbo or config.oci.packages.skopeo or pkgs.skopeo;
      canBuildTest = nixosModule != null && nixosTestModule != null && pkgs.stdenv.isLinux;

      # ── BDD spec containers (runtime/deploy) ────────────────
      vmSpecs = extractVmSpecs (config.test.oci.perContainer or { });
      runtimeSpecs = lib.filterAttrs (_: s: s.level == "runtime") vmSpecs;
      deploySpecs = lib.filterAttrs (_: s: s.level == "deploy") vmSpecs;

      loadableSpecs = runtimeSpecs // deploySpecs;

      # ── State-directory tmpfs backing ────────────────────────
      # Specs may declare `stateDirectories = [ "/var/lib/postgresql" ]`.
      # For each (spec, dir), we back it with a per-spec tmpfs on the
      # host at `/run/oci-test-state/<name>/<slug>` and inject a
      # `-v host:container` volume so the container sees a writable dir.
      # Slug replaces `/` with `_` because host paths must be flat.
      slugify = s: lib.replaceStrings [ "/" ] [ "_" ] (lib.removePrefix "/" s);
      stateHostBase = "/run/oci-test-state";
      stateMountsForSpec =
        name: spec:
        lib.map (dir: {
          hostPath = "${stateHostBase}/${name}/${slugify dir}";
          containerPath = dir;
        }) (spec.stateDirectories or [ ]);
      # All (spec × dir) pairs, flat, for fileSystems declarations.
      allStateMounts = lib.concatLists (lib.mapAttrsToList stateMountsForSpec loadableSpecs);

      # Flake-only container attributes that do NOT exist on the deploy-side
      # (nixos) `oci.containers.<name>` submodule. Per the 3-tier option
      # architecture (see MEMORY.md, "Key Design Decisions"): `test.*` opts
      # (probe enable flags, container-structure-test config, coherence, etc.)
      # live only on the flake-side per-container submodule. If a spec sets
      # them via `container.test.<probe>.enabled = true` to drive flake-side
      # probe-app synthesis (see nix/modules/oci/testing/test-apps.nix), those
      # flags are meaningless here and would produce
      #   `The option 'nodes.machine.oci.containers.<X>.test' does not exist`.
      # Strip before merging into bddContainers.
      flakeOnlyContainerKeys = [ "test" ];
      stripFlakeOnly = c: builtins.removeAttrs c flakeOnlyContainerKeys;

      bddContainers = lib.mapAttrs (
        name: spec:
        let
          extraStateVolumes = lib.map (m: "${m.hostPath}:${m.containerPath}") (stateMountsForSpec name spec);
          existingVolumes = spec.container.volumes or [ ];
          deployContainer = stripFlakeOnly spec.container;
        in
        deployContainer
        // lib.optionalAttrs (extraStateVolumes != [ ]) {
          volumes = existingVolumes ++ extraStateVolumes;
        }
        // lib.optionalAttrs (spec.level == "runtime") {
          autoStart = true;
          mode = "oneshot";
        }
        // lib.optionalAttrs (spec.level == "deploy") {
          autoStart = true;
          mode = "daemon";
        }
      ) loadableSpecs;
      bddContainerNames = lib.attrNames bddContainers;

      testableSpecs = runtimeSpecs // deploySpecs;
      hasTestableSpecs = testableSpecs != { };

      # ── Flake-level containers: build deps only ─────────────
      # All flake example images must build successfully, but they are
      # NOT pushed into the VM. Only one is pushed to test the registry
      # pipeline. The rest are validated at build time.
      flakeContainerNames = lib.attrNames (config.oci.containers or { });
      hasFlakeContainers = flakeContainerNames != [ ];
      flakeOCIs = lib.listToAttrs (
        lib.map (name: lib.nameValuePair name config.oci.internal.OCIs.${name}) flakeContainerNames
      );

      # Pick one small flake container to test the registry push pipeline.
      # "example-hello" is the smallest (just pkgs.hello).
      flakeOCINames = lib.attrNames flakeOCIs;
      registryTestName =
        if builtins.hasAttr "example-hello" flakeOCIs then
          "example-hello"
        else if flakeOCINames != [ ] then
          lib.head (lib.sort (a: b: a < b) flakeOCINames)
        else
          null;
      registryTestOCI = if registryTestName != null then flakeOCIs.${registryTestName} or null else null;

      hasAnyContainers = bddContainers != { } || hasFlakeContainers;

      # ── Pytest code for BDD specs ───────────────────────────
      pytestCode = lib.concatMapStringsSep "\n\n" (
        name:
        let
          spec = vmSpecs.${name};
        in
        pythonGen.mkPytestFunction {
          containerName = name;
          inherit (spec) assertions;
          given = spec.given or "";
          "when" = spec."when" or "";
          "then" = spec."then" or "";
        }
      ) (lib.attrNames testableSpecs);

      registryLowerName = if registryTestName != null then lib.toLower registryTestName else "";

      testSuiteFile = pkgs.writeText "test_bdd_vm.py" ''
        import docker
        import json
        import pytest

        @pytest.fixture(scope="session")
        def client():
            return docker.from_env()

        ${pytestCode}

        def test_registry_push_pipeline(client):
            """The registry push pipeline works: skopeo nix: -> registry -> podman pull."""
            images = client.images.list()
            image_tags = [t for img in images for t in (img.tags or [])]
            assert any("${registryLowerName}" in t for t in image_tags), (
                f"Expected '${registryLowerName}' in loaded images, got: {image_tags}"
            )
      '';

      # ── Build-time deps: all flake OCI images must build ────
      # These are added as extraBuildInputs so `nix build` the check
      # transitively builds all example images, but they never enter the VM.
      flakeOCIsList = lib.attrValues flakeOCIs;
    in
    {
      # Internal: derivation stored here, exposed via checks.e2e in the consuming flake.
      test.oci._bddVmCheck = lib.mkIf (canBuildTest && hasAnyContainers) (
        testHelpers.mkVMTest {
          name = "nix-oci-bdd-vm";

          # Ensure all flake example images build before the VM runs.
          # They are NOT loaded into the VM — just build-validated.
          passthru.flakeOCIs = flakeOCIs;

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [ nixosModule ] ++ lib.optional (nixosTestModule != null) nixosTestModule;

              # When `_vmBackend = "docker"`, we still get podman from the
              # test module's `_podman-config.nix` (which we cannot remove
              # without churn in shared test infra); we additionally
              # enable dockerd so the deploy suite can be exercised
              # against docker via the same VM. The pytest driver picks
              # the right socket via `DOCKER_HOST` in the testScript.
              virtualisation.docker.enable = lib.mkIf (config.test.oci._vmBackend == "docker") true;

              # Per-spec writable tmpfs mounts backing each declared
              # `stateDirectories` entry. Sized modestly (256 MiB each)
              # so a PostgreSQL initdb has room without dominating the
              # VM's overall memory budget.
              fileSystems = lib.listToAttrs (
                lib.map (m: {
                  name = m.hostPath;
                  value = {
                    device = "tmpfs";
                    fsType = "tmpfs";
                    options = [
                      "size=256m"
                      "mode=0755"
                    ];
                  };
                }) allStateMounts
              );

              # BDD containers go through the deploy module
              oci = {
                enable = true;
                backend = config.test.oci._vmBackend;
                perContainer = [
                  (
                    { lib, ... }:
                    {
                      config.layerStrategy = lib.mkDefault "fine-grained";
                      config.optimizeLayers = lib.mkDefault true;
                    }
                  )
                ];
                containers = bddContainers;
              };

              # Single registry push test: push one small image to validate
              # the skopeo nix: -> registry -> podman pull pipeline.
              systemd.services = lib.optionalAttrs (registryTestOCI != null) {
                "flake-oci-load-${registryTestName}" = {
                  description = "Push ${registryTestName} to local registry (pipeline test)";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "docker-registry.service" ];
                  requires = [ "docker-registry.service" ];
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                  };
                  path = [
                    skopeoNix2container
                    pkgs.podman
                  ];
                  script = ''
                    set -euo pipefail
                    for _i in $(seq 1 60); do
                      if ${pkgs.curl}/bin/curl -sf http://localhost:5000/v2/ >/dev/null 2>&1; then
                        break
                      fi
                      sleep 0.5
                    done
                    echo "Pushing ${registryTestName} to local registry ..."
                    skopeo --insecure-policy copy \
                      --dest-tls-verify=false \
                      nix:${registryTestOCI} \
                      docker://localhost:5000/${registryLowerName}:latest
                    echo "Pulling from registry ..."
                    podman pull --tls-verify=false \
                      localhost:5000/${registryLowerName}:latest
                    echo "Successfully loaded ${registryTestName}"
                  '';
                };
              };

              environment.systemPackages = [
                (pkgs.python3.withPackages (
                  ps: with ps; [
                    docker
                    pytest
                    requests
                  ]
                ))
              ];
            };

          testScript =
            let
              backend = config.test.oci._vmBackend or "podman";
              socketUnit = if backend == "docker" then "docker.socket" else "podman.socket";
              containerServicePrefix = if backend == "docker" then "docker-" else "podman-";
              dockerHost =
                if backend == "docker" then "unix:///var/run/docker.sock" else "unix:///run/podman/podman.sock";
            in
            ''
              machine.wait_for_unit("multi-user.target")
              machine.wait_for_unit("${socketUnit}")
              machine.wait_for_unit("docker-registry.service")

              # Wait for BDD container images to be loaded
              ${lib.concatMapStringsSep "\n" (
                name: ''machine.wait_for_unit("oci-load-${name}.service")''
              ) bddContainerNames}

              # Wait for BDD runtime/deploy container services
              ${lib.concatMapStringsSep "\n" (
                name: ''machine.wait_for_unit("${containerServicePrefix}${name}.service")''
              ) (lib.attrNames (runtimeSpecs // deploySpecs))}

              # Wait for the single registry push test
              ${lib.optionalString (registryTestOCI != null) ''
                machine.wait_for_unit("flake-oci-load-${registryTestName}.service")
              ''}

              # Run all pytest assertions
              machine.copy_from_host("${testSuiteFile}", "/tmp/test_bdd_vm.py")
              machine.succeed(
                  "cd /tmp && DOCKER_HOST=${dockerHost} "
                  "pytest test_bdd_vm.py -v --tb=short 2>&1"
              )
            '';
        }
      );
    };
}
