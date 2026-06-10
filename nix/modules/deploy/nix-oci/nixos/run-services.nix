# NixOS: forward autoStart containers to virtualisation.oci-containers,
# wire loader as dependency of the runner, open firewall for exposed ports,
# and apply runtime performance tuning (cgroup v2, OCI runtime, tmpfs).
#
# NOTE: sdnotify health-aware services are disabled until nix2container
# upstream bug #197 is fixed (Healthcheck dropped from image config).
# The infrastructure (hasHealthcheck, healthcheckConfig, Type=notify) is
# ready in image.nix and can be re-enabled once Healthcheck works.
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
      autoStart = lib.filterAttrs (_: c: c.autoStart) cfg.containers;

      # Extract all host ports across all autoStart containers for the firewall.
      allHostPorts = lib.concatMap (
        container:
        map (
          portSpec:
          let
            raw = builtins.head (lib.splitString ":" portSpec);
            clean = builtins.head (lib.splitString "/" raw);
          in
          lib.toInt clean
        ) container.ports
      ) (lib.attrValues autoStart);

      # Compute extra container runtime flags from performance.runtime options.
      mkPerfOpts =
        container:
        let
          perf = container.performance.runtime or { };
        in
        lib.optional ((perf.ociRuntime or null) != null) "--runtime=${perf.ociRuntime}"
        ++ map (m: "--tmpfs=${m}") (perf.tmpfsMounts or [ ]);
    in
    {
      config = lib.mkIf (cfg.enable && autoStart != { }) {
        virtualisation.oci-containers = {
          backend = cfg.backend;
          containers = lib.mapAttrs (
            _name: container:
            let
              secOpts = container.securityOpts or [ ];
              perfOpts = mkPerfOpts container;
              allExtraOpts = secOpts ++ perfOpts;
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
        networking.firewall.allowedTCPPorts = allHostPorts;

        # Runner depends on loader + cgroup v2 performance tuning
        systemd.services = lib.mapAttrs' (
          name: container:
          let
            serviceName =
              config.virtualisation.oci-containers.containers.${name}.serviceName or "${cfg.backend}-${name}";
            perf = container.performance.runtime or { };
          in
          lib.nameValuePair serviceName {
            after = [ "oci-load-${name}.service" ];
            requires = [ "oci-load-${name}.service" ];
            serviceConfig =
              lib.optionalAttrs ((perf.memoryHigh or null) != null) {
                MemoryHigh = perf.memoryHigh;
              }
              // lib.optionalAttrs ((perf.cpuBurst or null) != null) {
                CPUBurst = perf.cpuBurst;
              };
          }
        ) autoStart;
      };
    };
}
