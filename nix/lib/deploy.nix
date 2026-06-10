# Pure deploy helper functions for OCI container management.
#
# Shared by NixOS, home-manager, and system-manager deploy modules.
# Wrapped by nix-lib (nix/modules/oci/lib/deploy.nix).
{ lib }:
let
  ociLib = import ./oci.nix { inherit lib; };

  # Compute extra container runtime flags from performance.runtime options.
  # These become --flag arguments to docker/podman run.
  mkPerfOpts =
    container:
    let
      perf = container.performance.runtime or { };
      ulimits = perf.ulimits or { };
    in
    # Runtime selection
    lib.optional ((perf.ociRuntime or null) != null) "--runtime=${perf.ociRuntime}"
    # Memory limits
    ++ lib.optional ((perf.memory or null) != null) "--memory=${perf.memory}"
    ++ lib.optional (
      (perf.memoryReservation or null) != null
    ) "--memory-reservation=${perf.memoryReservation}"
    # CPU limits
    ++ lib.optional ((perf.cpus or null) != null) "--cpus=${perf.cpus}"
    ++ lib.optional ((perf.cpuSetCpus or null) != null) "--cpuset-cpus=${perf.cpuSetCpus}"
    ++ lib.optional ((perf.cpuSetMems or null) != null) "--cpuset-mems=${perf.cpuSetMems}"
    # I/O
    ++ lib.optional ((perf.ioWeight or null) != null) "--blkio-weight=${toString perf.ioWeight}"
    # Process limits
    ++ lib.optional ((perf.pidsLimit or null) != null) "--pids-limit=${toString perf.pidsLimit}"
    # OOM
    ++ lib.optional ((perf.oomScoreAdj or null) != null) "--oom-score-adj=${toString perf.oomScoreAdj}"
    # Filesystem
    ++ map (m: "--tmpfs=${m}") (perf.tmpfsMounts or [ ])
    ++ lib.optional ((perf.shmSize or null) != null) "--shm-size=${perf.shmSize}"
    # Ulimits
    ++ lib.optional (
      (ulimits.nofile or null) != null
    ) "--ulimit=nofile=${toString ulimits.nofile}:${toString ulimits.nofile}"
    ++ lib.optional (
      (ulimits.memlock or null) != null
    ) "--ulimit=memlock=${ulimits.memlock}:${ulimits.memlock}"
    ++ lib.optional (
      (ulimits.nproc or null) != null
    ) "--ulimit=nproc=${toString ulimits.nproc}:${toString ulimits.nproc}"
    # Logging
    ++ lib.optional ((perf.logDriver or null) != null) "--log-driver=${perf.logDriver}"
    # Sysctls
    ++ lib.mapAttrsToList (k: v: "--sysctl=${k}=${v}") (perf.sysctls or { });
in
{
  inherit mkPerfOpts;
  # Select the backend-specific copy script for loading an image.
  # Returns the nix2container copy derivation (copyToDockerDaemon or copyToPodman).
  copyScript =
    {
      backend,
      container,
    }:
    if backend == "docker" then container.image.copyToDockerDaemon else container.image.copyToPodman;

  # Filter containers that have autoStart enabled.
  autoStartContainers = containers: lib.filterAttrs (_: c: c.autoStart) containers;

  # Extract all host ports across containers for firewall rules.
  allHostPorts =
    containers:
    lib.concatMap (container: map (portSpec: ociLib.parseHostPort portSpec) container.ports) (
      lib.attrValues containers
    );

  # Compute podman healthcheck + sdnotify flags.
  # Injects --health-cmd at runtime to work around nix2container not
  # embedding Healthcheck in the image config (upstream bug #197).
  # The /bin/sh required by --health-cmd is provided by the healthcheck
  # NixOS module (adapterPackages) when a healthcheck is configured.
  mkHealthcheckOpts =
    container:
    let
      hc = container.healthcheckConfig or null;
    in
    if hc != null then
      [
        "--health-cmd=${lib.concatStringsSep " " hc.command}"
        "--health-interval=${toString hc.interval}s"
        "--health-timeout=${toString hc.timeout}s"
        "--health-start-period=${toString hc.startPeriod}s"
        "--health-retries=${toString hc.retries}"
        "--sdnotify=healthy"
      ]
    else
      [ ];

  # Build docker/podman run arguments for a container.
  mkRunArgs =
    name: container:
    let
      portArgs = lib.concatMap (p: [
        "-p"
        p
      ]) container.ports;
      envArgs = lib.concatLists (
        lib.mapAttrsToList (k: v: [
          "-e"
          "${k}=${v}"
        ]) container.environment
      );
      volumeArgs = lib.concatMap (v: [
        "-v"
        v
      ]) container.volumes;
      secOpts = container.securityOpts or [ ];
      perfOpts = mkPerfOpts container;
    in
    [
      "run"
      "--rm"
      "--name"
      name
    ]
    ++ portArgs
    ++ envArgs
    ++ volumeArgs
    ++ secOpts
    ++ perfOpts
    ++ [ container.imageRef ];
}
