# Pure deploy helper functions for OCI container management.
#
# Shared by NixOS, home-manager, and system-manager deploy modules.
# Wrapped by nix-lib (nix/modules/oci/lib/deploy.nix).
{ lib }:
let
  ociLib = import ./oci.nix { inherit lib; };
in
{
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

  # Compute extra container runtime flags from performance.runtime options.
  mkPerfOpts =
    container:
    let
      perf = container.performance.runtime or { };
    in
    lib.optional ((perf.ociRuntime or null) != null) "--runtime=${perf.ociRuntime}"
    ++ map (m: "--tmpfs=${m}") (perf.tmpfsMounts or [ ]);

  # Extract all host ports across containers for firewall rules.
  allHostPorts =
    containers:
    lib.concatMap (
      container:
      map (portSpec: ociLib.parseHostPort portSpec) container.ports
    ) (lib.attrValues containers);

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
    ++ [ container.imageRef ];
}
