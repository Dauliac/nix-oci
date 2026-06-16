# NixOS: forward autoStart containers to virtualisation.oci-containers,
# wire loader as dependency of the runner, open firewall for exposed ports,
# apply runtime performance tuning (cgroup v2, OCI runtime, tmpfs),
# and enable sdnotify health-aware services when healthcheck is present.
#
# Healthcheck is injected via podman --health-cmd at runtime as a workaround
# for nix2container upstream bug #197 (Healthcheck dropped from image config).
# The /bin/sh required by --health-cmd is provided by the healthcheck module.
{ ... }:
{
  flake.modules.nixos.nix-oci-run-services =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.oci;
      reg = cfg.registry;
      deployLib = import ../../../../lib/deploy.nix { inherit lib; };
      autoStart = deployLib.autoStartContainers cfg.containers;
      useRegistry = reg.enable;
    in
    {
      config = lib.mkIf (cfg.enable && autoStart != { }) {
        virtualisation.oci-containers = {
          backend = cfg.backend;
          containers = lib.mapAttrs (
            _name: container:
            let
              secOpts = container.securityOpts or [ ];
              perfOpts = deployLib.mkPerfOpts container;
              healthOpts = if cfg.backend == "podman" then deployLib.mkHealthcheckOpts container else [ ];
              allExtraOpts =
                secOpts
                ++ perfOpts
                ++ healthOpts
                # Allow pulling from insecure local registry.
                ++ lib.optional useRegistry "--tls-verify=false";
              imageRef =
                if useRegistry then
                  deployLib.registryImageRef {
                    registry = reg;
                    inherit container;
                  }
                else
                  container.imageRef;
            in
            {
              image = imageRef;
              # Registry path: pull from registry (enables SOCI lazy pull).
              # Direct path: never pull (image already loaded locally).
              pull = if useRegistry then "always" else "never";
            }
            // lib.optionalAttrs (container.ports != [ ]) {
              ports = container.ports;
            }
            // lib.optionalAttrs (container.environment != { }) {
              environment = container.environment;
            }
            // lib.optionalAttrs (container.volumes != [ ]) {
              volumes = container.volumes;
            }
            // lib.optionalAttrs (allExtraOpts != [ ]) {
              extraOptions = allExtraOpts;
            }
          ) autoStart;
        };

        # Auto-open firewall for exposed host ports
        networking.firewall.allowedTCPPorts = deployLib.allHostPorts autoStart;

        # Runner depends on loader + sdnotify + cgroup v2 performance tuning.
        # Systemd service properties provide finer cgroup v2 control than
        # container runtime flags alone (MemoryHigh, MemoryMin, CPUWeight, etc.).
        systemd.services = lib.mapAttrs' (
          name: container:
          let
            serviceName =
              config.virtualisation.oci-containers.containers.${name}.serviceName or "${cfg.backend}-${name}";
            hasHc = container.hasHealthcheck or false;
            useSdnotify = cfg.backend == "podman" && hasHc;
            perf = container.performance.runtime or { };
            ulimits = perf.ulimits or { };
          in
          lib.nameValuePair serviceName {
            after = [ "oci-load-${name}.service" ];
            requires = [ "oci-load-${name}.service" ];
            serviceConfig =
              # Oneshot mode: run once, don't restart, record exit status.
              # mkForce overrides oci-containers.nix's Type=notify default.
              lib.optionalAttrs ((container.mode or "daemon") == "oneshot") {
                Type = lib.mkForce "oneshot";
                RemainAfterExit = true;
                Restart = lib.mkForce "no";
              }
              # sdnotify: Type=notify + NotifyAccess=all so systemd waits
              # for the healthcheck READY=1 before starting dependents.
              // lib.optionalAttrs (useSdnotify && (container.mode or "daemon") != "oneshot") {
                Type = lib.mkForce "notify";
                NotifyAccess = "all";
              }
              # cgroup v2 memory controls (supplements --memory from container runtime)
              // lib.optionalAttrs ((perf.memoryHigh or null) != null) {
                MemoryHigh = perf.memoryHigh;
              }
              // lib.optionalAttrs ((perf.memoryMin or null) != null) {
                MemoryMin = perf.memoryMin;
              }
              # cgroup v2 CPU controls
              // lib.optionalAttrs ((perf.cpuWeight or null) != null) {
                CPUWeight = perf.cpuWeight;
              }
              # cgroup v2 I/O controls
              // lib.optionalAttrs ((perf.ioWeight or null) != null) {
                IOWeight = perf.ioWeight;
              }
              # OOM priority
              // lib.optionalAttrs ((perf.oomScoreAdj or null) != null) {
                OOMScoreAdjust = perf.oomScoreAdj;
              }
              # Ulimits via systemd
              // lib.optionalAttrs ((ulimits.nofile or null) != null) {
                LimitNOFILE = ulimits.nofile;
              }
              // lib.optionalAttrs ((ulimits.memlock or null) != null) {
                LimitMEMLOCK = ulimits.memlock;
              }
              // lib.optionalAttrs ((ulimits.nproc or null) != null) {
                LimitNPROC = ulimits.nproc;
              };
          }
        ) autoStart;
      };
    };
}
