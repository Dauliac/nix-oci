+++
title = "Automatic metadata derivation"
description = "How nix-oci auto-derives healthchecks, stop signals, working directories, and volume declarations from NixOS service configuration"
+++

# Automatic metadata derivation

nix-oci automatically derives OCI image metadata from NixOS module
configuration. This page covers the four auto-derived fields beyond
labels (which have [their own page](./automatic-labeling.md)).

## Automatic healthcheck provisioning

When using `nixosConfig` with a `mainService`, nix-oci **automatically
derives** a healthcheck from the NixOS module configuration — no manual
setup required.

```nix
# The user writes this:
oci.containers.db = {
  nixosConfig.enable = true;
  nixosConfig.mainService = "postgresql";
  nixosConfig.modules = [{ services.postgresql.enable = true; }];
};

# And automatically gets:
# -> OCI Healthcheck: pg_isready -h localhost -p 5432
# -> Deploy: --sdnotify=healthy (Podman waits for health before READY=1)
```

### How it works

Service adapters in `_nixos/oci/service-adapters/` introspect the
actual NixOS module configuration to build a healthcheck tailored to
the service:

| Service | What the adapter inspects | Derived command |
|---|---|---|
| **nginx** | `virtualHosts.*.listen` (port, SSL), `locations` (scans for `/health`, `/healthz`, `stub_status`) | `curl -f http[s]://localhost:${port}${bestPath}` |
| **PostgreSQL** | `settings.port`, `package` | `pg_isready -h localhost -p ${port}` |
| **Redis** | `servers.<name>.port`, `servers.<name>.bind` | `redis-cli -h ${bind} -p ${port} ping` |

The nginx adapter also automatically adds `curl` to
`environment.systemPackages` so the healthcheck binary is available
inside the container.

### Why it matters

- **Zero configuration**: the most common failure mode with container
  healthchecks is forgetting to set one, or setting one that doesn't
  match the actual service configuration. Auto-derivation eliminates
  both.
- **Correct by construction**: the healthcheck is derived from the same
  NixOS options that configure the service. If you change the PostgreSQL
  port to 5433, the healthcheck automatically updates.
- **Systemd-aware**: with Podman's `--sdnotify=healthy`, the healthcheck
  feeds into systemd's service dependency graph. A database container
  reports as "ready" only when it's actually accepting connections —
  dependent services don't start prematurely.
- **Overridable**: adapters use `lib.mkDefault`, so users can always
  replace the auto-derived command with their own.

### Deploy-side systemd integration

When a container has a healthcheck and the backend is Podman, the deploy
modules automatically wire:

1. **`--sdnotify=healthy`** on the `podman run` command
2. **`Type=notify`** + **`NotifyAccess=all`** on the systemd service

This means Podman sends `sd_notify(READY=1)` to systemd only after the
healthcheck passes for the first time. Any service depending on the
container (via `After` + `Requires`) waits until the container is
genuinely healthy.

Without healthcheck integration, systemd considers a container "ready"
the instant `podman run` starts — even if the application inside takes
seconds to initialize. This race condition is a common source of
intermittent failures in multi-container deployments.

## StopSignal — correct graceful shutdown

Different services require different signals for graceful shutdown.
Sending `SIGTERM` (the default) to nginx kills workers mid-request;
the correct signal is `SIGQUIT`. Service adapters encode this knowledge:

| Service | Signal | Effect |
|---|---|---|
| **nginx** | `SIGQUIT` | Finish serving current requests, then exit |
| **PostgreSQL** | `SIGINT` | Rollback active transactions, clean exit |
| **Redis** | `SIGTERM` | Save dataset and exit |

When no adapter is present, the signal is derived from the systemd
`KillSignal` in the NixOS service config.

## WorkingDir — context-aware working directory

The working directory is resolved from four sources in priority order:

1. Explicit `workingDir` option
2. systemd `WorkingDirectory` from the service config
3. NixOS `services.<name>.dataDir` (e.g., `/var/lib/postgresql`)
4. User home directory (`/root` or `/home/<user>`)

This ensures that PostgreSQL containers start in `/var/lib/postgresql`
and nginx containers start in the correct document root — without any
manual configuration.

## Declared volumes — data directory hints from systemd

NixOS services declare their data directories via systemd:
`StateDirectory`, `RuntimeDirectory`, `CacheDirectory`, `LogsDirectory`.
nix-oci translates these into OCI `Volumes` metadata:

```
StateDirectory = "postgresql"  ->  Volumes: { "/var/lib/postgresql": {} }
RuntimeDirectory = "nginx"     ->  Volumes: { "/run/nginx": {} }
```

This tells container orchestrators which paths contain persistent data
that should survive container restarts — without requiring the user to
repeat this information.

## Further reading

- [Automatic OCI labels](./automatic-labeling.md) — auto-generated labels from package metadata
- [Container metadata wiring](./container-metadata-wiring.md) — how all options flow into OCI config
- [Design choices](./design-choices.md) — overview of all defaults and rationale
