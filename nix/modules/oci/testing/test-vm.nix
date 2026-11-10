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

  # Groups whose scenarios cannot run in the aggregate bdd-vm.
  #
  # - "probes-e2e": needs per-container `_app-vm` infrastructure
  #   (probe-app synthesis, oci.testing.appVm.apps) that only the
  #   `bdd-app-*` matrix wires. The spec containers use a dummy
  #   `pkgs.hello` with `test.<probe>.enabled = true`, so loading
  #   them in bdd-vm boots the dummy but never executes the probe
  #   app that would write to /tmp/nix-oci-reports. Pytest then
  #   asserts on an empty dir and fails.
  #
  # - "deploy-bind": blocked by a nixpkgs 25.11 regression. The
  #   `services.bind` module's `configFile` derivation runs
  #     named-checkconf -z $target -t ${cfg.directory}
  #   in its preCheck. BIND 9.20 is strict about argument order
  #   (options must precede the positional named.conf path), so
  #   `-z <file> -t <dir>` prints usage and the derivation fails
  #   with "builder failed with exit code 255" before any container
  #   can be built. Reproduced locally and verified against the
  #   nixpkgs source at
  #   `nixos/modules/services/networking/bind.nix`. Needs an
  #   upstream fix (reorder args or set doCheck = false) that is
  #   out of scope for this repo. Re-include this group once
  #   nixpkgs ships the fix.
  bddVmExcludedGroups = [
    "probes-e2e"
    "deploy-bind"
  ];

  extractVmSpecs =
    allSpecs:
    lib.concatMapAttrs (
      group: scenarios:
      if lib.elem group bddVmExcludedGroups then
        { }
      else
        lib.concatMapAttrs (
          name: spec:
          if spec.level == "runtime" || spec.level == "deploy" then { "${group}--${name}" = spec; } else { }
        ) scenarios
    ) allSpecs;

  # Assertion types that only ever observe a container through a
  # registry push, never a direct podman/docker load: sociZtocPresent
  # (zTOC generation is a push-time skopeo transform) and
  # compressionApplied (compression is only ever applied via skopeo's
  # --dest-compress-format flag at push time, see load-services.nix).
  # Used by aggNeedsRegistry/shardNeedsRegistry below to flip
  # oci.registry.enable on for any shard containing such a spec.
  specNeedsRegistry =
    s:
    (s.assertions.sociZtocPresent or null) != null || (s.assertions.compressionApplied or null) != null;
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
        description = ''
          Aggregate BDD VM test derivation running every runtime/deploy
          spec in a single VM. Kept as a compatibility alias; the
          parallelizable variant lives in `_bddVmChecks`.
        '';
      };
      options.test.oci._bddVmChecks = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        default = { };
        internal = true;
        description = ''
          Per-group BDD VM test derivations (one VM per spec-group
          prefix). Consumed by the main flake as
          `checks.<system>.bdd-vm-<group>` so Nix's build scheduler
          parallelises them and GitHub Actions can shard them across
          runners. Shorter per-shard wall clock also sidesteps Azure
          spot preemption that was killing the single aggregate VM.
        '';
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

      # ── State-directory writable backing ──────────────────────
      # Specs may declare `stateDirectories = [ "/var/lib/postgresql" ]`.
      # For each (spec, dir), we back it with a per-spec writable directory
      # on the host at `/run/oci-test-state/<name>/<slug>` and inject a
      # `-v host:container` volume so the container sees a writable dir.
      # Slug replaces `/` with `_` because host paths must be flat.
      #
      # Originally backed by a dedicated per-spec `fileSystems` tmpfs mount
      # plus `RequiresMountsFor` ordering on the container's systemd unit.
      # That did not hold up in CI: the container still hit
      # `Error: statfs <path>: no such file or directory` even with the
      # ordering wired correctly (confirmed via direct eval), while a
      # plain `systemd.tmpfiles.rules`-based directory pre-creation (used
      # for bind-mount sources below) worked cleanly in the same run.
      #
      # These directories must additionally be OWNED by the container's
      # resolved user, not root: a container with `mainService` set but
      # no `isRoot = true` runs as that service's auto-derived non-root
      # user (e.g. "postgres") from the start (matches real NixOS: the
      # service's systemd unit sets `User = "postgres"`, with the data
      # directory provisioned by systemd's own StateDirectory mechanism,
      # not by the service's own preStart/execStart). A root-owned,
      # root:root-only host directory would make the first `initdb`
      # call fail with "cannot be run as root" (if isRoot=true) or
      # "Permission denied" (if isRoot=false but the directory isn't
      # writable by that user) regardless of podman's own user mapping.
      # Resolving the correct ownership needs the container's OWN final
      # evaluated config (user name -> numeric uid/gid via its NixOS
      # eval's users.users/users.groups), which -- like the apparmor
      # profile wiring above -- is only reachable via a nested
      # `{ config, ... }` import, not the pre-called outer node function.
      slugify = s: lib.replaceStrings [ "/" ] [ "_" ] (lib.removePrefix "/" s);
      stateHostBase = "/run/oci-test-state";
      stateMountsForSpec =
        name: spec:
        lib.map (dir: {
          hostPath = "${stateHostBase}/${name}/${slugify dir}";
          containerPath = dir;
        }) (spec.stateDirectories or [ ]);
      hasStateDirs = s: (s.stateDirectories or [ ]) != [ ];

      # ── Probe-container hardening kwargs ───────────────────────
      # BDD `syscallBlocked`/`fsWriteBlocked`/`succeeds`/`fails` assertions
      # run a fresh, ephemeral probe container directly against the image
      # (`client.containers.run(image, ...)`), separate from the autoStart
      # systemd-managed container that actually carries the computed
      # `securityOpts` (seccomp/apparmor/cap-drop/read-only flags, see
      # `_containers/security.nix`). Without this, the probe inherits none
      # of the hardening under test: seccomp/capabilities/rootfs scenarios
      # silently exercise podman/docker's bare defaults instead of the
      # container's configured hardening, and any apparent "pass" (e.g. a
      # /proc/sys write failing due to the default capability set lacking
      # CAP_SYS_ADMIN) can be a false positive unrelated to the feature
      # under test.
      #
      # `config.oci.containers.${name}.securityOpts` (reachable only via a
      # nested `{ config, ... }` module, same reason as stateDirTmpfilesRulesFor
      # above) is a list of raw `--flag=value` CLI strings. Parse it into a
      # structured attrset so it can be serialized as JSON and consumed by
      # docker-py kwargs in the generated pytest file (see
      # _python-gen.nix's `_hardening_kwargs`).
      parseSecurityOpts =
        opts:
        lib.foldl' (
          acc: opt:
          if lib.hasPrefix "--security-opt=seccomp=" opt then
            acc // { seccomp_profile_path = lib.removePrefix "--security-opt=seccomp=" opt; }
          else if lib.hasPrefix "--security-opt=apparmor=" opt then
            acc // { apparmor_profile = lib.removePrefix "--security-opt=apparmor=" opt; }
          else if opt == "--security-opt=no-new-privileges" then
            acc // { no_new_privileges = true; }
          else if opt == "--read-only" then
            acc // { read_only = true; }
          else if lib.hasPrefix "--cap-drop=" opt then
            acc // { cap_drop = (acc.cap_drop or [ ]) ++ [ (lib.removePrefix "--cap-drop=" opt) ]; }
          else if lib.hasPrefix "--cap-add=" opt then
            acc // { cap_add = (acc.cap_add or [ ]) ++ [ (lib.removePrefix "--cap-add=" opt) ]; }
          else if lib.hasPrefix "--tmpfs=" opt then
            let
              rest = lib.removePrefix "--tmpfs=" opt;
              parts = lib.splitString ":" rest;
              path = lib.head parts;
              mountOpts = lib.concatStringsSep ":" (lib.tail parts);
            in
            acc
            // {
              tmpfs = (acc.tmpfs or { }) // {
                ${path} = mountOpts;
              };
            }
          else
            acc
        ) { } opts;

      probeHardeningJsonFor =
        config: names:
        builtins.toJSON (
          lib.listToAttrs (
            lib.map (
              name: lib.nameValuePair name (parseSecurityOpts (config.oci.containers.${name}.securityOpts or [ ]))
            ) names
          )
        );

      stateDirTmpfilesRulesFor =
        config: names:
        lib.concatMap (
          name:
          let
            container = config.oci.containers.${name};
            userName = container.user;
            userEntry = container.nixosConfig.eval.users.users.${userName};
            groupEntry = container.nixosConfig.eval.users.groups.${userEntry.group};
          in
          lib.map (m: "d ${m.hostPath} 0700 ${toString userEntry.uid} ${toString groupEntry.gid} -") (
            stateMountsForSpec name loadableSpecs.${name}
          )
        ) names;

      # ── Host-side bind-mount source directories ───────────────
      # Specs may declare `container.volumes = [ "/run/foo:/bar" ]` to bind-
      # mount a host directory the test populates at assertion time (see
      # deploy/wiring-volumes.test.nix). podman does NOT auto-create
      # missing bind-mount *source* directories -- it fails the container
      # with `Error: statfs <path>: no such file or directory`. Pre-create
      # every such host path via tmpfiles so it exists before the
      # container's systemd unit ever tries to start (tmpfiles-setup.service
      # is ordered via sysinit.target, well before any container unit).
      # Unlike state dirs above, these are test-populated scratch dirs with
      # no particular owner requirement, so plain root:root is fine.
      volumeHostPath = v: lib.head (lib.splitString ":" v);
      volumeHostPathsForSpec = spec: lib.map volumeHostPath (spec.container.volumes or [ ]);
      allVolumeHostPaths = lib.unique (
        lib.concatMap volumeHostPathsForSpec (lib.attrValues loadableSpecs)
      );

      # apparmor.service wiring for the aggregate VM (see usesApparmor in
      # mkBddVmFor for the per-shard equivalent and rationale).
      aggBackend = config.test.oci._vmBackend;
      aggContainerServicePrefix = if aggBackend == "docker" then "docker-" else "podman-";
      # See shardNeedsRegistry in mkBddVmFor for the full rationale.
      aggNeedsRegistry = lib.any specNeedsRegistry (lib.attrValues loadableSpecs);
      aggUsesApparmor =
        s: (s.container.hardening.enable or false) && (s.container.hardening.apparmor.enable or false);
      allApparmorNames = lib.attrNames (lib.filterAttrs (_: aggUsesApparmor) loadableSpecs);
      allStateDirNames = lib.attrNames (lib.filterAttrs (_: hasStateDirs) loadableSpecs);
      allStateRequires = lib.mapAttrs' (
        name: _:
        lib.nameValuePair "${aggContainerServicePrefix}${name}" {
          after = [ "apparmor.service" ];
          requires = [ "apparmor.service" ];
        }
      ) (lib.filterAttrs (_: aggUsesApparmor) loadableSpecs);

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
          # testDependencies (_option-test-spec.nix) is declared on the spec
          # but was never actually merged anywhere -- a dead option. Without
          # this, a scenario like runtime-tls-handshake-fails declares
          # `testDependencies = [ pkgs.curl ]` expecting curl on PATH, but
          # the built image only ever contains `container.package`'s own
          # closure, so the probe fails with "executable file `curl` not
          # found in $PATH" instead of exercising the TLS assertion.
          existingDeps = spec.container.dependencies or [ ];
          extraTestDeps = spec.testDependencies or [ ];
        in
        deployContainer
        // lib.optionalAttrs (extraTestDeps != [ ]) {
          dependencies = existingDeps ++ extraTestDeps;
        }
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

      # Loads /etc/nix-oci-test-hardening.json (see probeHardeningJsonFor)
      # and exposes `_hardening_kwargs(name)`, which the generated
      # assertion code (_python-gen.nix) splats into every ephemeral probe
      # container's `client.containers.run(...)` call so probes actually
      # exercise the container's configured hardening instead of
      # podman/docker's bare defaults.
      hardeningPreamble = ''
        with open("/etc/nix-oci-test-hardening.json") as _hf:
            _HARDENING = json.load(_hf)


        def _hardening_security_opt(h):
            # podman's REST API (unlike the CLI) resolves `seccomp=<value>`
            # server-side: it treats the value as a path and opens it
            # itself, rather than accepting inline profile JSON. The test
            # client and the podman daemon share the same VM filesystem, so
            # passing the Nix store path straight through (exactly what the
            # real autoStart container's --security-opt gets) works; passing
            # the file's content instead makes podman try to open() the
            # whole JSON blob as a path and fail with "file name too long".
            opts = []
            if h.get("seccomp_profile_path"):
                opts.append("seccomp=" + h["seccomp_profile_path"])
            if h.get("apparmor_profile"):
                opts.append("apparmor=" + h["apparmor_profile"])
            if h.get("no_new_privileges"):
                opts.append("no-new-privileges")
            return opts


        def _hardening_kwargs(name):
            h = _HARDENING.get(name, {})
            kwargs = {}
            security_opt = _hardening_security_opt(h)
            if security_opt:
                kwargs["security_opt"] = security_opt
            if h.get("cap_drop"):
                kwargs["cap_drop"] = h["cap_drop"]
            if h.get("cap_add"):
                kwargs["cap_add"] = h["cap_add"]
            if h.get("read_only"):
                kwargs["read_only"] = True
            if h.get("tmpfs"):
                kwargs["tmpfs"] = h["tmpfs"]
            return kwargs
      '';

      testSuiteFile = pkgs.writeText "test_bdd_vm.py" ''
        import docker
        import json
        import pytest

        @pytest.fixture(scope="session")
        def client():
            return docker.from_env()

        ${hardeningPreamble}

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

      # ── Per-group spec sharding ────────────────────────────
      # Specs are keyed `<group>--<scenario>`. Bucket by the first
      # dash-separated token of the group (`deploy`, `runtime`,
      # `hardening`, `performance`, `probes`, ...) so GitHub Actions
      # can fan them out across runners. Each shard VM boots ~5-10
      # containers instead of ~44, finishes in under 5 min, and so
      # avoids the Azure spot preemption that was killing the single
      # aggregate VM (see 091aef2, 953e3f3 postmortems).
      #
      # One shard (prefer `deploy-a`, else `deploy`, else
      # alphabetically-first) carries the registry-push test so it
      # runs exactly once.
      #
      # `performance`'s 13 groups all share that first token, so by
      # default they'd all land in one shard -- 14 containers booting
      # concurrently in a single VM, which was overrunning the 30min
      # CI job timeout (likely CPU contention: the VM requests more
      # vCPUs than the GH-hosted runner actually has). Split it across
      # two shards via an explicit override, same ~7 containers each.
      # Keys here are the group as it actually appears in spec keys
      # (`<group>--<scenario>`), which is the `test.oci.perContainer`
      # attribute name with the spec's `level` appended -- e.g. the
      # `performance-allocator-config` test group at `level = "runtime"`
      # produces group key `performance-allocator-config-runtime`.
      performanceShardOverride =
        lib.genAttrs [
          "performance-allocator-runtime"
          "performance-allocator-config-runtime"
          "performance-hwcaps-runtime"
          "performance-enable-runtime"
          "performance-huge-pages-runtime"
          "performance-startup-runtime"
        ] (_: "performance-a")
        // lib.genAttrs [
          "performance-glibc-tunables-runtime"
          "performance-glibc-tunables-preset-runtime"
          "performance-turbo-enable-runtime"
          "performance-turbo-layer-cache-runtime"
        ] (_: "performance-b")
        # performance-turbo-soci-runtime's and performance-compression-
        # runtime's scenarios both need oci.registry.enable = true (see
        # specNeedsRegistry / shardNeedsRegistry below): sociZtocPresent
        # and compressionApplied both only observe a container once it's
        # actually pushed through the registry, and nothing else pushes
        # these specific images there otherwise. Kept in their own
        # shard rather than flipping that switch for the whole
        # performance-b VM: registry push+pull round-trips for every
        # one of performance-b's other unrelated containers would add
        # boot time this shard doesn't have slack for (see the
        # 30min-CI-timeout history comment above mkBddVmFor).
        // lib.genAttrs [
          "performance-turbo-soci-runtime"
          "performance-compression-runtime"
        ] (_: "performance-c");

      # `deploy`'s 8 groups all share that first token too, and the
      # shard also runs the flake-level registry-push smoke test by
      # default (see `registryHostGroup` below). CI run 42209149129
      # (and the repeat after the dnsmasq healthcheck fix, run
      # 42216807543) both hit the 30min job timeout: the job log shows
      # `oci-load-deploy-dnsmasq.service` sitting in `wait_for_unit`
      # for 486-594s while the registry-push test's own skopeo
      # copy/podman pull stalls on repeated "blob unknown" registry
      # 404s -- real contention over the VM's single local registry,
      # not a per-group slowness problem (the other 7 groups each go
      # healthy within ~35s once that contention clears). `deploy-bind`
      # is excluded from the VM entirely (see `bddVmExcludedGroups`
      # above) so it does not factor into either shard. Split the
      # remaining 8 groups into two 4-container shards, same pattern
      # as `performanceShardOverride`, to roughly halve the registry
      # contention each shard's boot has to absorb. Keys are the group
      # as it appears in spec keys (`<group>--<scenario>`), same shape
      # as above -- deploy groups don't get a level suffix since each
      # has exactly one scenario.
      deployShardOverride =
        lib.genAttrs [
          "deploy-dnsmasq"
          "deploy-docker-backend"
          "deploy-phpfpm"
          "deploy-postgresql"
        ] (_: "deploy-a")
        // lib.genAttrs [
          "deploy-wiring-deps"
          "deploy-wiring-env"
          "deploy-wiring-ports"
          "deploy-wiring-volumes"
        ] (_: "deploy-b");

      groupPrefix =
        name:
        let
          group = lib.head (lib.splitString "--" name);
          parts = lib.splitString "-" group;
          firstToken = if parts == [ ] then "misc" else builtins.head parts;
        in
        performanceShardOverride.${group} or deployShardOverride.${group} or firstToken;

      loadableSpecsByGroup =
        let
          groups = lib.groupBy (name: groupPrefix name) (lib.attrNames loadableSpecs);
        in
        lib.mapAttrs (_: names: lib.getAttrs names loadableSpecs) groups;

      registryHostGroup =
        if lib.hasAttr "deploy-a" loadableSpecsByGroup then
          "deploy-a"
        else if lib.hasAttr "deploy" loadableSpecsByGroup then
          "deploy"
        else if loadableSpecsByGroup != { } then
          lib.head (lib.sort builtins.lessThan (lib.attrNames loadableSpecsByGroup))
        else
          null;

      # Shard-level VM builder. Called once per group to produce the
      # matrix entry, and once with all specs to produce the backward-
      # compat aggregate `_bddVmCheck`.
      mkBddVmFor =
        {
          shardName,
          shardSpecs,
          includeRegistryTest,
        }:
        let
          shardRuntime = lib.filterAttrs (_: s: s.level == "runtime") shardSpecs;
          shardDeploy = lib.filterAttrs (_: s: s.level == "deploy") shardSpecs;
          shardVolumeHostPaths = lib.unique (
            lib.concatMap volumeHostPathsForSpec (lib.attrValues shardSpecs)
          );
          shardStateDirNames = lib.attrNames (lib.filterAttrs (_: hasStateDirs) shardSpecs);
          # Containers with hardening.apparmor.enable need the host's
          # apparmor.service to have loaded their named profile before they
          # start (symptom: `Error: apparmor profile "nix-oci-<name>"
          # specified, but Apparmor is not enabled on this system`) -- see
          # the `security.apparmor` block below, which registers the
          # already-generated profile for each such container.
          #
          # A spec may set `requiresBackend = "docker";` to pin its whole
          # shard to a specific backend regardless of the project-wide
          # `_vmBackend` default. Needed because nixpkgs' podman is built
          # without the Go "apparmor" build tag (its AppArmor detection is
          # permanently stubbed to false), so any apparmor-enforcement
          # scenario has to run under docker instead; see
          # apparmor-docker.test.nix. Specs within one shard must agree --
          # put a backend-pinned spec in its own dedicated shard (group
          # name with a unique first dash-token, see groupPrefix above)
          # rather than mixing it into an existing one.
          shardRequiresBackend =
            let
              backends = lib.unique (
                lib.filter (b: b != null) (lib.mapAttrsToList (_: s: s.requiresBackend or null) shardSpecs)
              );
            in
            if backends == [ ] then
              null
            else if lib.length backends == 1 then
              lib.head backends
            else
              throw "nix-oci test-vm: shard ${shardName} mixes requiresBackend values ${toString backends}; put each in its own shard";
          shardBackend =
            if shardRequiresBackend != null then shardRequiresBackend else config.test.oci._vmBackend;
          containerServicePrefix = if shardBackend == "docker" then "docker-" else "podman-";
          usesApparmor =
            s: (s.container.hardening.enable or false) && (s.container.hardening.apparmor.enable or false);
          shardApparmorNames = lib.attrNames (lib.filterAttrs (_: usesApparmor) shardSpecs);
          # sociZtocPresent and compressionApplied both only observe a
          # specific repo:tag as actually pushed to the registry.
          # oci.registry.enable switches oci-load from a direct
          # podman/docker load to a registry push (nix2container's
          # copyToRegistry), using repo:tag =
          # lib.toLower container.name:container.tag -- see
          # nix/modules/deploy/nix-oci/nixos/load-services.nix and
          # nix/lib/deploy.nix's registryImageRef. Nothing else pushes
          # these images there otherwise.
          shardNeedsRegistry = lib.any specNeedsRegistry (lib.attrValues shardSpecs);
          shardStateRequires = lib.mapAttrs' (
            name: _:
            lib.nameValuePair "${containerServicePrefix}${name}" {
              after = [ "apparmor.service" ];
              requires = [ "apparmor.service" ];
            }
          ) (lib.filterAttrs (_: usesApparmor) shardSpecs);
          shardBddContainers = lib.getAttrs (lib.attrNames shardSpecs) bddContainers;
          shardBddContainerNames = lib.attrNames shardBddContainers;
          shardPytestCode = lib.concatMapStringsSep "\n\n" (
            name:
            let
              spec = shardSpecs.${name};
            in
            pythonGen.mkPytestFunction {
              containerName = name;
              inherit (spec) assertions;
              given = spec.given or "";
              "when" = spec."when" or "";
              "then" = spec."then" or "";
            }
          ) (lib.attrNames shardSpecs);
          shardTestSuiteFile = pkgs.writeText "test_bdd_vm_${shardName}.py" ''
            import docker
            import json
            import pytest

            @pytest.fixture(scope="session")
            def client():
                return docker.from_env()

            ${hardeningPreamble}

            ${shardPytestCode}
            ${lib.optionalString (includeRegistryTest && registryTestOCI != null) ''

              def test_registry_push_pipeline_loaded(client):
                  """Verify the registry-pushed image was pulled into podman."""
                  images = client.images.list()
                  image_tags = [t for img in images for t in (img.tags or [])]
                  assert any("${registryLowerName}" in t for t in image_tags), (
                      f"Expected '${registryLowerName}' in loaded images, got: {image_tags}"
                  )
            ''}
          '';
        in
        testHelpers.mkVMTest {
          name = "nix-oci-bdd-vm-${shardName}";
          passthru.flakeOCIs = if includeRegistryTest then flakeOCIs else { };
          nodes.machine =
            { pkgs, ... }:
            {
              imports = [
                nixosModule
                ./_vm-defaults
              ]
              ++ lib.optional (nixosTestModule != null) nixosTestModule
              # Load each apparmor-hardened container's generated profile
              # into the host kernel so podman's
              # `--security-opt apparmor=<name>` has something to apply
              # (see shardExtraUnitFor above). Nested as a module so
              # `config` resolves to this node's own final evaluated
              # config (self-referential, standard NixOS module idiom) --
              # mkVMTest pre-calls the outer node function with only
              # `{ pkgs, lib }`, so `config` is not available at this level.
              ++ lib.optional (shardApparmorNames != [ ]) (
                { config, ... }:
                {
                  security.apparmor = {
                    enable = true;
                    policies = lib.listToAttrs (
                      lib.map (
                        name:
                        lib.nameValuePair "nix-oci-${name}" {
                          path =
                            config.oci.containers.${name}.nixosConfig.eval.oci.container._output.hardening.apparmorProfile;
                        }
                      ) shardApparmorNames
                    );
                  };
                  # docker's AppArmor detection (containerd's vendored
                  # pkg/apparmor, no Go build tag gate -- unlike podman,
                  # whose nixpkgs build lacks AppArmor support entirely)
                  # hardcodes a check for /sbin/apparmor_parser, an FHS
                  # path NixOS does not populate by default: apparmor_parser
                  # only exists at its Nix store path, referenced directly
                  # by apparmor.service's own ExecStart. Shim it in so
                  # containerd's hostSupports() can actually find it.
                  # Mirrors NixOS's own /lib64 compat-symlink convention.
                  systemd.tmpfiles.rules = [
                    "d /sbin 0755 root root -"
                    "L+ /sbin/apparmor_parser - - - - ${pkgs.apparmor-parser}/bin/apparmor_parser"
                  ];
                }
              )
              # Owner-aware tmpfiles rules for stateDirectories hosts paths
              # (see stateDirTmpfilesRulesFor above); same nested-module
              # requirement as the apparmor block -- needs this node's own
              # resolved config to look up each container's numeric uid/gid.
              ++ lib.optional (shardStateDirNames != [ ]) (
                { config, ... }:
                {
                  systemd.tmpfiles.rules = stateDirTmpfilesRulesFor config shardStateDirNames;
                }
              )
              # Expose each BDD container's real computed hardening flags
              # (securityOpts) to the pytest probe invocations. See
              # probeHardeningJsonFor above for the rationale.
              ++ lib.optional (shardBddContainerNames != [ ]) (
                { config, ... }:
                {
                  environment.etc."nix-oci-test-hardening.json".text =
                    probeHardeningJsonFor config shardBddContainerNames;
                }
              );

              virtualisation.docker.enable = lib.mkIf (shardBackend == "docker") true;
              # The shared test module's _podman-config.nix unconditionally
              # enables virtualisation.podman.dockerSocket (so podman can
              # emulate the docker socket for podman-backed shards), which
              # conflicts with virtualisation.docker.enable -- both would try
              # to serve the same socket. No existing shard forces the global
              # _vmBackend to "docker", so this conflict was never actually
              # exercised before a requiresBackend = "docker" spec existed.
              virtualisation.podman.dockerSocket.enable = lib.mkIf (shardBackend == "docker") (lib.mkForce false);

              # The 4096 MiB _vm-defaults baseline is sized for direct
              # podman/docker loads. Pushing through the registry adds
              # the registry daemon's own footprint plus concurrent
              # skopeo copy processes buffering blobs over HTTP rather
              # than writing straight into containers-storage -- confirmed
              # OOMing the VM (kernel panic, panic_on_oom) on a stock
              # GitHub Actions runner with just 2 containers, so this
              # isn't host-contention noise.
              virtualisation.memorySize = lib.mkIf shardNeedsRegistry (lib.mkForce 8192);

              systemd.tmpfiles.rules = lib.map (p: "d ${p} 0755 root root -") shardVolumeHostPaths;

              oci = {
                enable = true;
                backend = shardBackend;
                registry.enable = lib.mkIf shardNeedsRegistry true;
                perContainer = [
                  (
                    { lib, ... }:
                    {
                      config.layerStrategy = lib.mkDefault "fine-grained";
                      config.optimizeLayers = lib.mkDefault true;
                    }
                  )
                ];
                containers = shardBddContainers;
              };

              systemd.services =
                shardStateRequires
                // lib.optionalAttrs (includeRegistryTest && registryTestOCI != null) {
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
                # `nft` for assertions.runtime scripts that inspect the
                # firewall ruleset directly (e.g. the wiring-ports test).
                # Not pulled in automatically just by having a firewall
                # enabled: nixpkgs' firewall module drives nft via its
                # own full store paths internally, it doesn't put the
                # binary on the general system PATH.
                pkgs.nftables
              ];
            };

          testScript =
            let
              # shardBackend (not the global _vmBackend) so a spec's
              # `requiresBackend` override actually takes effect here too.
              backend = shardBackend;
              socketUnit = if backend == "docker" then "docker.socket" else "podman.socket";
              containerServicePrefix = if backend == "docker" then "docker-" else "podman-";
              dockerHost =
                if backend == "docker" then "unix:///var/run/docker.sock" else "unix:///run/podman/podman.sock";
            in
            ''
              machine.wait_for_unit("multi-user.target")
              machine.wait_for_unit("${socketUnit}")
              ${lib.optionalString (includeRegistryTest && registryTestOCI != null) ''
                machine.wait_for_unit("docker-registry.service")
              ''}

              ${lib.concatMapStringsSep "\n" (
                name: ''machine.wait_for_unit("oci-load-${name}.service")''
              ) shardBddContainerNames}

              ${lib.concatMapStringsSep "\n" (
                name: ''machine.wait_for_unit("${containerServicePrefix}${name}.service")''
              ) (lib.attrNames (shardRuntime // shardDeploy))}

              ${lib.optionalString (includeRegistryTest && registryTestOCI != null) ''
                machine.wait_for_unit("flake-oci-load-${registryTestName}.service")
              ''}

              machine.copy_from_host("${shardTestSuiteFile}", "/tmp/test_bdd_vm.py")
              machine.succeed(
                  "cd /tmp && DOCKER_HOST=${dockerHost} "
                  "pytest test_bdd_vm.py -v --tb=short 2>&1"
              )
            '';
        };
    in
    {
      # Per-group matrix: one VM per BDD prefix bucket. Short per-shard
      # runtime avoids the Azure spot preemption that was killing the
      # single aggregate VM at 4-15 min marks.
      test.oci._bddVmChecks = lib.mkIf (canBuildTest && hasAnyContainers) (
        lib.mapAttrs (
          shardName: shardSpecs:
          mkBddVmFor {
            inherit shardName shardSpecs;
            includeRegistryTest = shardName == registryHostGroup;
          }
        ) loadableSpecsByGroup
      );

      # Aggregate: every spec in one VM. Kept for backward compat;
      # consumers should prefer `_bddVmChecks` to parallelise.
      test.oci._bddVmCheck = lib.mkIf (canBuildTest && hasAnyContainers) (
        testHelpers.mkVMTest {
          name = "nix-oci-bdd-vm";

          # Ensure all flake example images build before the VM runs.
          # They are NOT loaded into the VM — just build-validated.
          passthru.flakeOCIs = flakeOCIs;

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [
                nixosModule
                # Shared VM sizing + boot-speed defaults. Historically
                # only the per-container `_app-vm` tests inherited
                # these; without them, this aggregate VM fell back to
                # the NixOS test default disk (~1 GiB) and ran out of
                # space while loading the ~44 OCI images into
                # containers-storage, aborting with
                # `writing blob: ... no space left on device`.
                # The defaults set `diskSize = 32768` (32 GiB), which
                # the per-container VMs explicitly downsize via
                # `_app-vm`.
                ./_vm-defaults
              ]
              ++ lib.optional (nixosTestModule != null) nixosTestModule
              # See the equivalent nested module in mkBddVmFor for why this
              # is a nested `{ config, ... }` import rather than a plain
              # attribute on this node: mkVMTest pre-calls this outer node
              # function with only `{ pkgs, lib }`, so `config` (the node's
              # own final evaluated config) is only reachable one level
              # deeper, via NixOS's real module evaluator.
              ++ lib.optional (allApparmorNames != [ ]) (
                { config, ... }:
                {
                  security.apparmor = {
                    enable = true;
                    policies = lib.listToAttrs (
                      lib.map (
                        name:
                        lib.nameValuePair "nix-oci-${name}" {
                          path =
                            config.oci.containers.${name}.nixosConfig.eval.oci.container._output.hardening.apparmorProfile;
                        }
                      ) allApparmorNames
                    );
                  };
                  # See the matching shim in mkBddVmFor for why this exists:
                  # docker's (unlike podman's) AppArmor detection is real but
                  # hardcodes a check for /sbin/apparmor_parser, an FHS path
                  # NixOS does not populate by default.
                  systemd.tmpfiles.rules = [
                    "d /sbin 0755 root root -"
                    "L+ /sbin/apparmor_parser - - - - ${pkgs.apparmor-parser}/bin/apparmor_parser"
                  ];
                }
              )
              # Owner-aware tmpfiles rules for stateDirectories host paths
              # (see stateDirTmpfilesRulesFor above and the per-shard
              # equivalent in mkBddVmFor for the full rationale).
              ++ lib.optional (allStateDirNames != [ ]) (
                { config, ... }:
                {
                  systemd.tmpfiles.rules = stateDirTmpfilesRulesFor config allStateDirNames;
                }
              )
              # See the matching shard-level block in mkBddVmFor.
              ++ lib.optional (bddContainerNames != [ ]) (
                { config, ... }:
                {
                  environment.etc."nix-oci-test-hardening.json".text = probeHardeningJsonFor config bddContainerNames;
                }
              );

              # When `_vmBackend = "docker"`, we still get podman from the
              # test module's `_podman-config.nix` (which we cannot remove
              # without churn in shared test infra); we additionally
              # enable dockerd so the deploy suite can be exercised
              # against docker via the same VM. The pytest driver picks
              # the right socket via `DOCKER_HOST` in the testScript.
              virtualisation.docker.enable = lib.mkIf (aggBackend == "docker") true;

              # See shardNeedsRegistry's memorySize override in mkBddVmFor.
              virtualisation.memorySize = lib.mkIf aggNeedsRegistry (lib.mkForce 8192);

              systemd.tmpfiles.rules = lib.map (p: "d ${p} 0755 root root -") allVolumeHostPaths;

              # BDD containers go through the deploy module
              oci = {
                enable = true;
                backend = aggBackend;
                registry.enable = lib.mkIf aggNeedsRegistry true;
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
              systemd.services =
                allStateRequires
                // lib.optionalAttrs (registryTestOCI != null) {
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
                # `nft` for assertions.runtime scripts that inspect the
                # firewall ruleset directly (e.g. the wiring-ports test).
                # Not pulled in automatically just by having a firewall
                # enabled: nixpkgs' firewall module drives nft via its
                # own full store paths internally, it doesn't put the
                # binary on the general system PATH.
                pkgs.nftables
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
