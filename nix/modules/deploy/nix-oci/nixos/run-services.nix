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
      deployLib = import ../../../../lib/deploy.nix { inherit lib; };
      autoStart = deployLib.autoStartContainers cfg.containers;
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
              healthOpts =
                if cfg.backend == "podman" then deployLib.mkHealthcheckOpts container else [ ];
              allExtraOpts = secOpts ++ perfOpts ++ healthOpts;
            in
            {
              image = container.imageRef;
              pull = "never";
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

        # Runner depends on loader + sdnotify + cgroup v2 performance tuning
        systemd.services = lib.mapAttrs' (
          name: container:
          let
            serviceName =
              config.virtualisation.oci-containers.containers.${name}.serviceName or "${cfg.backend}-${name}";
            perf = container.performance.runtime or { };
            hasHc = container.hasHealthcheck or false;
            useSdnotify = cfg.backend == "podman" && hasHc;
          in
          lib.nameValuePair serviceName {
            after = [ "oci-load-${name}.service" ];
            requires = [ "oci-load-${name}.service" ];
            serviceConfig =
              # sdnotify: Type=notify + NotifyAccess=all so systemd waits
              # for the healthcheck READY=1 before starting dependents.
              lib.optionalAttrs useSdnotify {
                Type = "notify";
                NotifyAccess = "all";
              }
              // lib.optionalAttrs ((perf.memoryHigh or null) != null) {
                MemoryHigh = perf.memoryHigh;
              }
              // lib.optionalAttrs ((perf.memoryMax or null) != null) {
                MemoryMax = perf.memoryMax;
              }
              // lib.optionalAttrs ((perf.cpuBurst or null) != null) {
                CPUBurst = perf.cpuBurst;
              }
              // lib.optionalAttrs ((perf.cpuQuota or null) != null) {
                CPUQuota = perf.cpuQuota;
              }
              // lib.optionalAttrs ((perf.tasksMax or null) != null) {
                TasksMax = perf.tasksMax;
              };
          }
        ) autoStart;
      };
    };
}
