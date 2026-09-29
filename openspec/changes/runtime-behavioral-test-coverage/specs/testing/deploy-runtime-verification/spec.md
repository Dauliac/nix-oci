## Purpose

Deploy-level runtime coverage for the parts of the deploy surface currently untested: home-manager module, system-manager module, docker backend toggle, SOCI snapshotter service, six service adapters, and the runner-service dual/triple-write wiring.

## ADDED Requirements

### Requirement: Home-manager deploy runtime

The test suite SHALL verify that the home-manager deploy module boots a user-level loader and runner and that the container's healthcheck succeeds.

#### Scenario: Loader unit reaches active
- **WHEN** the VM harness deploys a container via `nix-oci.modules.homeManager.nix-oci` for a test user
- **THEN** `systemctl --user status oci-load-<name>.service` reports the unit as `active (exited)`

#### Scenario: Podman quadlet runner is running with sdnotify=healthy
- **WHEN** the runner unit is started for a container that declares a healthcheck
- **THEN** the runner reaches `active (running)`, `SubState=running`, and its unit reports `Type=notify`

### Requirement: System-manager deploy runtime

The test suite SHALL verify that the system-manager deploy module boots a system-level loader and runner.

#### Scenario: Loader + runner active on a system-manager host
- **WHEN** the VM harness applies a system-manager profile that includes `nix-oci.modules.systemManager.nix-oci` with one container
- **THEN** both `oci-load-<name>.service` and the runner service reach `active`

### Requirement: Docker backend deploy runtime

The test suite SHALL verify that the deploy surface works when `_vmBackend = "docker"`.

#### Scenario: Same NixOS test passes with docker backend
- **WHEN** the existing `nixos-caddy` deploy scenario is re-run with `config.test.oci._vmBackend = "docker"`
- **THEN** the HTTP-response assertion passes just as it does with podman

### Requirement: SOCI snapshotter deploy

The test suite SHALL verify that the SOCI snapshotter service starts and that a SOCI-indexed image can be lazily pulled.

#### Scenario: SOCI snapshotter unit is active
- **WHEN** a NixOS test host is deployed with a container declaring `performance.turbo.soci = true` and `oci.deploy.backend = "docker"`
- **THEN** the `soci-snapshotter-grpc.service` unit reaches `active`

#### Scenario: Lazy pull actually starts before full layer download
- **WHEN** the SOCI-indexed image is pulled from the in-VM registry into containerd via the SOCI snapshotter
- **THEN** the container starts and responds to a probe request before all layer bytes have been fetched (measured by comparing pulled bytes to full layer size at the moment the container is ready)

### Requirement: Untested service adapters end-to-end

The test suite SHALL cover the six previously-untested service adapters (`postgresql`, `httpd`, `bind`, `dnsmasq`, `postfix`, `phpfpm`) at deploy level. vsftpd is deferred by design (no healthcheck available).

#### Scenario: PostgreSQL container serves queries
- **WHEN** a NixOS deploy test starts a PostgreSQL container with `mainService = "postgresql"` and writable tmpfs for `/var/lib/postgresql`
- **THEN** `psql -h localhost -U postgres -c 'SELECT 1'` from the host returns `1`

#### Scenario: httpd container returns 200 on health endpoint
- **WHEN** a deploy test starts an httpd container with `mainService = "httpd"`
- **THEN** `curl http://localhost:<port>/_nix_oci_health` returns HTTP 200

#### Scenario: BIND resolves version.bind
- **WHEN** a deploy test starts a BIND container with `mainService = "bind"`
- **THEN** `dig @localhost -p <port> version.bind chaos txt` returns a non-empty TXT record

#### Scenario: dnsmasq resolves a configured hosts entry
- **WHEN** a deploy test starts a dnsmasq container with a hosts entry `myservice 10.0.0.1`
- **THEN** `dig @<addr> -p <port> myservice` returns `10.0.0.1`

#### Scenario: Postfix reports ready
- **WHEN** a deploy test starts a Postfix container with `mainService = "postfix"`
- **THEN** `postfix status` inside the container reports the master pid

#### Scenario: PHP-FPM responds on FastCGI ping
- **WHEN** a deploy test starts a PHP-FPM container with `mainService = "phpfpm"` and its `/ping` endpoint enabled
- **THEN** a `cgi-fcgi` ping to the container's FastCGI socket returns `pong`

### Requirement: home-config test file unblocked

The test suite SHALL restore active coverage for the currently-disabled `home-config.test.nix`.

#### Scenario: home-config eval and build scenarios run
- **WHEN** `nix flake check` runs
- **THEN** at least one scenario in `home-config.test.nix` executes at level `build` (not skipped) without the current FIXME comment referencing `lib/services/lib.nix`

### Requirement: Ports triple-write wiring

The test suite SHALL verify that `ports` is written to all three destinations: OCI ExposedPorts, runner `--publish`, and NixOS `firewall.allowedTCPPorts`.

#### Scenario: All three destinations receive the value
- **WHEN** a deploy test starts a container with `ports = ["8080:80/tcp"]`
- **THEN** (a) the image's `ExposedPorts` contains `80/tcp`, (b) the runner unit's command line contains `--publish 8080:80`, and (c) `nft list ruleset` or the equivalent inspection shows port 8080 accepted on the input chain

#### Scenario: Firewall opens the port end-to-end
- **WHEN** the runner is active with the container listening on 80
- **THEN** an HTTP request from the host machine to `localhost:8080` on the VM returns the container's response

### Requirement: Environment dual-write wiring

The test suite SHALL verify that `environment` is written both to OCI Env and to the runner service `--env` flags.

#### Scenario: Both destinations receive the value
- **WHEN** a deploy test starts a container with `environment.MY_VAR = "hello"`
- **THEN** (a) the image's Env array contains `MY_VAR=hello` and (b) the runner unit's command line contains `--env MY_VAR=hello`

#### Scenario: Daemon-mode container process has the env var
- **WHEN** the runner is active
- **THEN** reading `/proc/<pid>/environ` for the container process shows `MY_VAR=hello`

### Requirement: Volumes wiring

The test suite SHALL verify declared volumes and deploy-only bind mounts.

#### Scenario: Declared volumes reach OCI Volumes
- **WHEN** a container is built with `declaredVolumes = ["/data"]`
- **THEN** the image config's `Volumes` field contains `/data`

#### Scenario: Deploy-only bind mount is visible in the container
- **WHEN** a deploy test starts a container with `volumes = ["/host-path:/container-path"]` and the host path contains a probe file
- **THEN** the probe file is readable at `/container-path` inside the running container

### Requirement: Systemd dependency wiring

The test suite SHALL verify that `dependencies` produces the expected systemd After/Requires ordering.

#### Scenario: Runner unit After includes the loader
- **WHEN** a deploy test starts a container with `dependencies = []` (default)
- **THEN** `systemctl show <runner>.service --property=After,Requires` includes `oci-load-<name>.service`

#### Scenario: Extra dependencies land in the runner unit
- **WHEN** a deploy test starts a container with `dependencies = ["postgresql.service"]`
- **THEN** the runner unit's After+Requires include `postgresql.service`
