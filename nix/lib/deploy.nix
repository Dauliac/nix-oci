# Pure deploy helper functions for OCI container management.
#
# Shared by NixOS, home-manager, and system-manager deploy modules.
# Wrapped by nix-lib (nix/modules/oci/lib/deploy.nix).
{ lib }:
let
  ociLib = import ./oci.nix { inherit lib; };

  networkPresetMap = {
    "web-server" = {
      "net.core.somaxconn" = "65535";
      "net.ipv4.tcp_fastopen" = "3";
      "net.ipv4.tcp_tw_reuse" = "1";
      "net.ipv4.tcp_fin_timeout" = "15";
      "net.ipv4.tcp_slow_start_after_idle" = "0";
      "net.ipv4.ip_local_port_range" = "1024 65535";
    };
    "high-throughput" = {
      "net.core.somaxconn" = "65535";
      "net.ipv4.tcp_fastopen" = "3";
      "net.ipv4.tcp_tw_reuse" = "1";
      "net.ipv4.tcp_fin_timeout" = "15";
      "net.ipv4.tcp_slow_start_after_idle" = "0";
      "net.ipv4.ip_local_port_range" = "1024 65535";
      "net.core.rmem_max" = "67108864";
      "net.core.wmem_max" = "67108864";
      "net.core.netdev_max_backlog" = "65535";
    };
    "low-latency" = {
      "net.core.somaxconn" = "65535";
      "net.ipv4.tcp_fastopen" = "3";
      "net.ipv4.tcp_tw_reuse" = "1";
      "net.ipv4.tcp_fin_timeout" = "15";
      "net.ipv4.tcp_slow_start_after_idle" = "0";
      "net.ipv4.ip_local_port_range" = "1024 65535";
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.default_qdisc" = "fq";
    };
  };

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
    # Sysctls (preset merged with explicit, explicit wins)
    ++ (
      let
        presetSysctls =
          if (perf.networkPreset or null) != null then networkPresetMap.${perf.networkPreset} else { };
        effectiveSysctls = presetSysctls // (perf.sysctls or { });
      in
      lib.mapAttrsToList (k: v: "--sysctl=${k}=${v}") effectiveSysctls
    );

  # Healthcheck flags understood by BOTH docker and podman.
  #
  # Injected at runtime to work around nix2container not embedding
  # Healthcheck in the image config (upstream bug #197), which means
  # these flags are the only thing that gives a deployed container a
  # healthcheck at all. The /bin/sh required by --health-cmd is
  # provided by the healthcheck NixOS module (adapterPackages) when a
  # healthcheck is configured.
  #
  # Split out from mkHealthcheckOpts because that bundled the
  # podman-only --sdnotify flag, so callers gated the whole thing on
  # podman and docker deploys silently got no healthcheck at all.
  mkHealthFlags =
    container:
    let
      hc = container.healthcheckConfig or null;
    in
    lib.optionals (hc != null) [
      "--health-cmd=${lib.concatStringsSep " " hc.command}"
      "--health-interval=${toString hc.interval}s"
      "--health-timeout=${toString hc.timeout}s"
      "--health-start-period=${toString hc.startPeriod}s"
      "--health-retries=${toString hc.retries}"
    ];

  # podman only: forward READY=1 to systemd once the first healthcheck
  # passes, so dependents wait for real readiness. docker has no
  # equivalent, and this is the only genuinely backend-specific part of
  # healthcheck wiring.
  mkSdnotifyFlags =
    container: lib.optional ((container.healthcheckConfig or null) != null) "--sdnotify=healthy";

  # Both together, for callers that are podman-only by construction
  # (the home-manager target, which asserts podman).
  mkHealthcheckOpts = container: mkHealthFlags container ++ mkSdnotifyFlags container;
in
{
  inherit mkPerfOpts;
  # Select the backend-specific copy script for loading an image.
  # Three paths:
  #   1. registry push (copyToRegistry) — enables SOCI lazy pull + layer dedup
  #   2. docker daemon (copyToDockerDaemon) — direct load into docker/containerd
  #   3. podman (copyToPodman) — direct load into containers-storage
  copyScript =
    {
      backend,
      container,
      registry ? null,
    }:
    if registry != null then
      container.image.copyToRegistry
    else if backend == "docker" then
      container.image.copyToDockerDaemon
    else
      container.image.copyToPodman;

  # Build the registry image reference for a container.
  # e.g. "localhost:5000/my-container:latest"
  # The repository part is lowercased (OCI spec requirement; podman
  # rejects mixed-case references)  -  keep in sync with imageRef.
  registryImageRef =
    {
      registry,
      container,
    }:
    "${registry.host}:${toString registry.port}/${lib.toLower container.name}:${container.tag}";

  # Filter containers that have autoStart enabled.
  autoStartContainers = containers: lib.filterAttrs (_: c: c.autoStart) containers;

  # Extract all host ports across containers for firewall rules.
  allHostPorts =
    containers:
    lib.concatMap (container: map (portSpec: ociLib.parseHostPort portSpec) container.ports) (
      lib.attrValues containers
    );

  inherit mkHealthFlags mkSdnotifyFlags mkHealthcheckOpts;

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
    # Without these the system-manager target produced containers with
    # no healthcheck at all: it is the only caller of mkRunArgs, and
    # the image config carries no Healthcheck either (nix2container
    # #197). --sdnotify is deliberately absent, since this path builds
    # a plain `docker run` / `podman run` ExecStart rather than a
    # notify-type unit.
    ++ mkHealthFlags container
    ++ [ container.imageRef ];
}
