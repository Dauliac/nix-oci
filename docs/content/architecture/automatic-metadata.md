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
derives** a healthcheck from the NixOS module configuration, with no manual
setup required.

```nix
# The user writes this:
oci.containers.db = {
  mainService = "postgresql";
  nixosConfig.modules = [{ services.postgresql.enable = true; }];
};

# And automatically gets:
# -> OCI Healthcheck: pg_isready -h localhost -p 5432
# -> Deploy: --sdnotify=healthy (Podman waits for health before READY=1)
```

See [`nixosConfig`](../reference/nix-oci-container-module-options.md) in the container module option reference.

### How it works

Service adapters in `_nixos/oci/service-adapters/` introspect the
actual NixOS module configuration to build a healthcheck tailored to
the service. For HTTP servers, adapters **inject native health endpoints**
into the service configuration when the user hasn't defined one.

#### HTTP services: health endpoint injection

HTTP servers need an endpoint to probe. Rather than falling back to `/`
(which might return 404 or a redirect), adapters inject a proper health
endpoint automatically:

| Service | What's injected | How | Health signal |
|---|---|---|---|
| **nginx** | `stub_status` server on `127.0.0.1:10246` | `appendHttpConfig` (raw `server{}` block) | Active connections + request count, proving nginx is processing |
| **httpd** | `mod_status` at `/_nix_oci_health` | `extraConfig` with `Require local` | Server uptime + worker status |
| **Caddy** | Nothing (built-in) | Admin API at `localhost:2019` already exists | Full config introspection |

The nginx injection is the most interesting case:

```nginx
# Injected via appendHttpConfig -- invisible to user's virtualHosts
server {
    listen 127.0.0.1:10246;
    server_name _;
    location / {
        stub_status on;
        access_log off;
    }
}
```

- **Localhost-only**: not externally accessible
- **Port 10246**: high port, works with non-root containers
- **No access logs**: doesn't pollute log output
- **Zero interference**: uses `appendHttpConfig`, not `virtualHosts`
- **`stub_status`**: proves nginx is genuinely serving, not just alive
- **Skipped when unnecessary**: if the user defined `/health`, `/healthz`,
  or a `stub_status` location, the adapter uses that instead

#### Priority chain for nginx healthcheck

1. User-defined health endpoint (`/health`, `/healthz`, `/ready`,
   `/nginx_status`, or any location with `stub_status`): uses the
   user's endpoint at the user's port/protocol
2. No health endpoint found: injects internal `stub_status` server
   and targets `http://127.0.0.1:10246/`

#### Non-HTTP services: native CLI tools

Services that don't serve HTTP already ship built-in health check tools
and require no adapter injection:

| Service | Native tool | Health signal |
|---|---|---|
| **PostgreSQL** | `pg_isready -h localhost -p ${port}` | Connection acceptance (proves DB is ready for queries) |
| **Redis** | `redis-cli -h ${bind} -p ${port} ping` | Server responsiveness |
| **BIND** | `dig @127.0.0.1 version.bind chaos txt` | DNS resolution capability |
| **dnsmasq** | `dig @${addr} -p ${port} localhost` | DNS resolution on configured address |
| **Postfix** | `postfix status` | Mail system master process status |

All adapters also inject the health check tool into
`environment.systemPackages` (curl for HTTP services, dig for DNS
services) so the binary is available inside the container image.

### Why it matters

- **Zero configuration**: the most common failure mode with container
  healthchecks is forgetting to set one, or setting one that doesn't
  match the actual service configuration. Auto-derivation eliminates
  both.
- **Correct by construction**: nix-oci derives the healthcheck from the
  same NixOS options that configure the service. If you change the PostgreSQL
  port to 5433, the healthcheck automatically updates.
- **No dummy probes**: instead of blindly curling `/` (which might 404),
  HTTP adapters inject a purpose-built health endpoint that provides a
  meaningful signal (connection counts, server status).
- **Systemd-aware**: with Podman's `--sdnotify=healthy`, the healthcheck
  feeds into systemd's service dependency graph. A database container
  reports as "ready" only when it's actually accepting connections --
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
the instant `podman run` starts, even if the application inside takes
seconds to initialize. This race condition is a common source of
intermittent failures in multi-container deployments.

## StopSignal: correct graceful shutdown

Different services require different signals for graceful shutdown.
Sending `SIGTERM` to nginx kills workers mid-request;
the correct signal is `SIGQUIT`. Service adapters encode this knowledge:

| Service | Signal | Effect |
|---|---|---|
| **nginx** | `SIGQUIT` | Graceful worker shutdown: finish serving current requests |
| **httpd** | `SIGWINCH` | Graceful stop: finish current requests (not `SIGTERM` which is immediate) |
| **Caddy** | `SIGTERM` | Graceful with connection draining |
| **PostgreSQL** | `SIGINT` | Fast shutdown: rollback active transactions, clean exit |
| **Redis** | `SIGTERM` | Save dataset (if configured) and exit |
| **BIND** | `SIGTERM` | Clean shutdown |
| **dnsmasq** | `SIGTERM` | Clean shutdown |
| **Postfix** | `SIGTERM` | Stop mail system |
| **vsftpd** | `SIGTERM` | Clean shutdown |

When no adapter covers the service, nix-oci reads the systemd
`KillSignal` from the NixOS service config instead.

## WorkingDir: context-aware working directory

nix-oci resolves the working directory from four sources in priority order:

1. Explicit `workingDir` option
2. systemd `WorkingDirectory` from the service config
3. NixOS `services.<name>.dataDir` (e.g., `/var/lib/postgresql`)
4. User home directory (`/root` or `/home/<user>`)

This ensures that PostgreSQL containers start in `/var/lib/postgresql`
and nginx containers start in the correct document root, without any
manual configuration.

## Declared volumes: data directory hints from systemd

NixOS services declare their data directories via systemd:
`StateDirectory`, `RuntimeDirectory`, `CacheDirectory`, `LogsDirectory`.
nix-oci translates these into OCI `Volumes` metadata:

```
StateDirectory = "postgresql"  ->  Volumes: { "/var/lib/postgresql": {} }
RuntimeDirectory = "nginx"     ->  Volumes: { "/run/nginx": {} }
```

This tells container orchestrators which paths contain persistent data
that should survive container restarts, without requiring the user to
repeat this information.

## Further reading

- [Automatic OCI labels](./automatic-labeling.md): auto-generated labels from package metadata
- [Container metadata wiring](./container-metadata-wiring.md): how all options flow into OCI config
- [Design choices](./design-choices.md): overview of all defaults and rationale
- [Container module options](../reference/nix-oci-container-module-options.md): full reference for `nixosConfig`, `mainService`, and all per-container options
- [flake-parts options](../reference/flake-parts-options.md): build-time container options
