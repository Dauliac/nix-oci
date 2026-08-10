# Pipeline composer — reads oci.pipeline.steps, generates outputs.
#
# For each container, produces a single package directory:
#   result/
#   ├── manifest.json         → nix2container image manifest
#   ├── gate                  → gate stamp (all checks passed)
#   ├── sbom.cdx.json         → CycloneDX SBOM (if syft enabled)
#   └── bin/
#       ├── push              → push to registry
#       ├── load-docker       → load into Docker
#       ├── load-podman       → load into Podman
#       └── sandbox           → bubblewrap shell
#
# Flake apps are thin wrappers: `nix run .#oci-push-myapp` → `result/bin/push`
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    types
    attrsets
    ;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { ... }:
    {
      options.oci.pipeline = {
        gates = mkOption {
          type = types.attrsOf types.attrs;
          internal = true;
          default = { };
          description = "Gated OCI images per container.";
        };
        gatedPackages = mkOption {
          type = types.attrsOf types.package;
          internal = true;
          default = { };
          description = "Assembled OCI packages (directory with manifest + bin/).";
        };
        prefixedGatedPackages = mkOption {
          type = types.attrsOf types.package;
          internal = true;
          default = { };
          description = "Prefixed gated packages for flake.packages output.";
        };
        apps = mkOption {
          type = types.attrsOf types.attrs;
          internal = true;
          default = { };
          description = "Pipeline apps: sandbox, push, load-docker, load-podman per container.";
        };
        checks = mkOption {
          type = types.attrsOf types.package;
          internal = true;
          default = { };
          description = "Gate checks per container.";
        };
      };
    }
  );

  config.perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
      hasOciLib = ociLib != { };
      steps = config.oci.pipeline.steps;
      defaultBackend = config.oci.pipeline.defaultBackend;

      resolveBackend =
        step:
        if step.backend != null then
          step.backend
        else if step.phase == "build-check" then
          "pure"
        else if step.phase == "probe" then
          defaultBackend
        else
          "daemon";

      enabledStepsFor =
        containerId:
        let
          containerConfig = config.oci.containers.${containerId};
        in
        lib.filterAttrs (_name: step: step.isEnabled containerConfig) steps;

      # ── Stamps (pure/vm checks for the gate) ────────────────

      gateStampsFor =
        containerId:
        let
          enabled = enabledStepsFor containerId;
          gateSteps = lib.filterAttrs (
            _: s:
            let
              b = resolveBackend s;
            in
            b == "pure" || b == "vm"
          ) enabled;
          mkStampFor =
            name: step:
            if step.mkStamp != null then
              {
                inherit name;
                stamp = step.mkStamp {
                  inherit containerId;
                  perSystemConfig = config.oci;
                };
                category = step.category;
              }
            else
              null;
        in
        lib.filter (s: s != null) (lib.attrValues (lib.mapAttrs mkStampFor gateSteps));

      # ── Scripts (daemon-backend steps) ──────────────────────

      daemonScriptsFor =
        containerId:
        let
          enabled = enabledStepsFor containerId;
          daemonSteps = lib.filterAttrs (_: s: resolveBackend s == "daemon" && s.mkScript != null) enabled;
        in
        lib.mapAttrs (
          name: step:
          step.mkScript {
            inherit containerId;
            perSystemConfig = config.oci;
          }
        ) daemonSteps;

      # ── Skopeo package for a container ──────────────────────

      skopeoFor =
        containerId:
        let
          containerConfig = config.oci.containers.${containerId};
        in
        if containerConfig.performance.turbo.enable or false then
          config.oci.packages.skopeoTurbo
        else
          config.oci.packages.skopeo;

      # ── Assembled package per container ─────────────────────
      #
      # Single derivation that produces:
      #   $out/manifest.json
      #   $out/gate               (stamp file, forces all checks)
      #   $out/sbom.cdx.json      (if sbom-syft stamp exists)
      #   $out/bin/push
      #   $out/bin/load-docker
      #   $out/bin/load-podman
      #   $out/bin/sandbox
      #   $out/bin/<probe-name>   (for each daemon-backend probe)

      mkPackageFor =
        containerId:
        let
          rawImage = config.oci.internal.OCIs.${containerId};
          containerConfig = config.oci.containers.${containerId};
          imageName = containerConfig.name;
          imageTag = containerConfig.tag;
          skopeo = skopeoFor containerId;

          stampEntries = gateStampsFor containerId;
          stamps = map (s: s.stamp) stampEntries;

          # Find the SBOM stamp if it exists (it writes the actual SBOM to $out)
          sbomStamp = lib.findFirst (s: s.category == "sbom") null stampEntries;

          # Push script (uses mkPushAllTagsApp internally)
          pushScript = ociLib.mkPushAllTagsApp {
            perSystemConfig = config.oci;
            inherit containerId;
          };

          # Sandbox script
          sandboxScript = config.oci.internal.sandboxApps.${containerId};

          # Load scripts
          loadDockerScript = pkgs.writeShellApplication {
            name = "load-docker-${containerId}";
            runtimeInputs = [ skopeo ];
            text = ''
              echo "[load-docker] Loading ${containerId} → docker-daemon:${imageName}:${imageTag}"
              exec skopeo --insecure-policy copy \
                "nix:${rawImage}" \
                "docker-daemon:${imageName}:${imageTag}"
            '';
          };

          loadPodmanScript = pkgs.writeShellApplication {
            name = "load-podman-${containerId}";
            runtimeInputs = [ skopeo ];
            text = ''
              echo "[load-podman] Loading ${containerId} → containers-storage:${imageName}:${imageTag}"
              exec skopeo --insecure-policy copy \
                "nix:${rawImage}" \
                "containers-storage:${imageName}:${imageTag}"
            '';
          };

          # Daemon probe scripts
          probeScripts = daemonScriptsFor containerId;

          # Collect phase-specific scripts
          mkPhaseScripts =
            phase:
            let
              enabled = enabledStepsFor containerId;
              phaseSteps = lib.filterAttrs (_: s: s.phase == phase && s.mkScript != null) enabled;
            in
            lib.mapAttrs (
              name: step:
              step.mkScript {
                inherit containerId;
                perSystemConfig = config.oci;
              }
            ) phaseSteps;

          prePushScripts = mkPhaseScripts "pre-push";
          postPushScripts = mkPhaseScripts "post-push";

          # Helper: run a set of scripts in parallel, fail if any fail
          mkParallelBlock =
            label: scripts:
            lib.optionalString (scripts != { }) ''
              echo "[${label}] Running ${toString (lib.length (lib.attrNames scripts))} step(s)..."
              pids=()
              ${lib.concatMapStringsSep "\n" (name: ''
                ${lib.getExe scripts.${name}} &
                pids+=($!)
                echo "[${label}] Started ${name} (pid $!)"
              '') (lib.attrNames scripts)}
              failed=0
              for pid in "''${pids[@]}"; do
                if ! wait "$pid"; then
                  ((failed++))
                fi
              done
              if [ "$failed" -gt 0 ]; then
                echo "[${label}] $failed step(s) failed"
                exit 1
              fi
              echo "[${label}] All steps completed"
            '';

          # Full push pipeline: pre-push (CVE) → push → post-push (sign)
          pushPipelineScript = pkgs.writeShellApplication {
            name = "push-${containerId}";
            runtimeInputs = [ ];
            text =
              (mkParallelBlock "pre-push" prePushScripts)
              + ''
                # Push all tags
                ${lib.getExe pushScript} "$@"
              ''
              + (mkParallelBlock "post-push" postPushScripts);
          };
        in
        pkgs.runCommandLocal "oci-${containerId}"
          {
            nativeBuildInputs = stamps;
            meta.description = "OCI image package for ${containerId} with validation gate and delivery scripts.";
          }
          ''
            mkdir -p $out/bin

            # Image manifest
            ln -s ${rawImage} $out/manifest.json

            # Gate stamp — proves all checks passed
            echo "gate: ${toString (lib.length stamps)} checks passed for ${containerId}" > $out/gate
            echo "image: ${rawImage}" >> $out/gate

            # SBOM artifact (symlink to the syft stamp output if it's a real file)
            ${lib.optionalString (sbomStamp != null) ''
              if [ -f "${sbomStamp.stamp}" ] && file "${sbomStamp.stamp}" | grep -q 'JSON'; then
                ln -s ${sbomStamp.stamp} $out/sbom.cdx.json
              fi
            ''}

            # Delivery scripts
            ln -s ${lib.getExe pushPipelineScript} $out/bin/push
            ln -s ${lib.getExe sandboxScript} $out/bin/sandbox
            ln -s ${lib.getExe loadDockerScript} $out/bin/load-docker
            ln -s ${lib.getExe loadPodmanScript} $out/bin/load-podman

            # Probe scripts (daemon-backend steps)
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: script: "ln -s ${lib.getExe script} $out/bin/${name}") probeScripts
            )}

            # Pre-push scripts (CVE/compliance — available for manual re-run)
            ${lib.optionalString (prePushScripts != { }) ''
              mkdir -p $out/bin/pre-push
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (
                  name: script: "ln -s ${lib.getExe script} $out/bin/pre-push/${name}"
                ) prePushScripts
              )}
            ''}

            # Post-push scripts (signing — available for manual re-run)
            ${lib.optionalString (postPushScripts != { }) ''
              mkdir -p $out/bin/post-push
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (
                  name: script: "ln -s ${lib.getExe script} $out/bin/post-push/${name}"
                ) postPushScripts
              )}
            ''}

            # Check stamps (symlinks for inspection)
            ${lib.optionalString (stampEntries != [ ]) ''
              mkdir -p $out/checks
              ${lib.concatMapStringsSep "\n" (s: "ln -s ${s.stamp} $out/checks/${s.name}") stampEntries}
            ''}
          '';
    in
    {
      oci.pipeline = {
        gates = attrsets.mapAttrs (containerId: _: mkPackageFor containerId) config.oci.containers;

        gatedPackages = attrsets.mapAttrs (containerId: _: mkPackageFor containerId) config.oci.containers;

        prefixedGatedPackages = cfg.lib.flake.oci.prefixOutputs {
          prefix = "oci-";
          set = config.oci.pipeline.gatedPackages;
        };

        apps =
          let
            outputs = cfg.oci.flake.outputs;

            # All apps just exec into the package's bin/ scripts
            sandboxApps = lib.optionalAttrs outputs.sandbox (
              attrsets.mapAttrs' (
                containerId: _:
                attrsets.nameValuePair "oci-sandbox-${containerId}" {
                  type = "app";
                  program = "${mkPackageFor containerId}/bin/sandbox";
                }
              ) config.oci.containers
            );

            pushApps = lib.optionalAttrs outputs.push (
              attrsets.mapAttrs' (
                containerId: _:
                attrsets.nameValuePair "oci-push-${containerId}" {
                  type = "app";
                  program = "${mkPackageFor containerId}/bin/push";
                }
              ) config.oci.containers
            );

            loadDockerApps = lib.optionalAttrs outputs.loadDocker (
              attrsets.mapAttrs' (
                containerId: _:
                attrsets.nameValuePair "oci-load-docker-${containerId}" {
                  type = "app";
                  program = "${mkPackageFor containerId}/bin/load-docker";
                }
              ) config.oci.containers
            );

            loadPodmanApps = lib.optionalAttrs outputs.loadPodman (
              attrsets.mapAttrs' (
                containerId: _:
                attrsets.nameValuePair "oci-load-podman-${containerId}" {
                  type = "app";
                  program = "${mkPackageFor containerId}/bin/load-podman";
                }
              ) config.oci.containers
            );
          in
          sandboxApps // pushApps // loadDockerApps // loadPodmanApps;

        checks =
          if cfg.oci.flake.outputs.checks then
            attrsets.mapAttrs' (
              containerId: _: attrsets.nameValuePair "oci-gate-${containerId}" (mkPackageFor containerId)
            ) config.oci.containers
          else
            { };
      };
    };
}
