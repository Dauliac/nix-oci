+++
title = "Container metadata wiring"
description = "How user options flow through nix-oci into OCI image config, systemd services, and firewall rules"
+++

# Container metadata wiring

nix-oci provides a **unified `oci.*` namespace** that works identically
across flake-parts (build-time), NixOS, and home-manager. Each option
you set on a container flows through multiple stages — from module
option, through OCI image configuration, to systemd services and
firewall rules.

This page maps that wiring for every metadata type.

## Overview

```mermaid
flowchart TD
    User["User options<br/>oci.containers.my-app.*"]

    subgraph build ["Build-time (nix2container)"]
        direction TB
        SharedOpts["Shared options<br/>_options/*.nix"]
        ImageNix["image.nix<br/>(computed, readOnly)"]
        OCI["OCI image config<br/>(entrypoint, User, Env,<br/>ExposedPorts, Labels,<br/>Healthcheck, StopSignal,<br/>WorkingDir, Volumes)"]
        Root["Root filesystem<br/>(mkRoot / mkShadowSetup)"]
        SharedOpts --> ImageNix
        ImageNix --> OCI
        ImageNix --> Root
    end

    subgraph deploy ["Deploy-time"]
        direction TB
        Loader["Loader service<br/>oci-load-&lt;name&gt;<br/>(copyToDockerDaemon / copyToPodman)"]
        Runner["Runner service<br/>(virtualisation.oci-containers<br/>or services.podman)"]
        FW["NixOS firewall<br/>networking.firewall.allowedTCPPorts"]
    end

    User --> SharedOpts
    OCI --> Loader
    Loader -->|"After + Requires"| Runner
    User -->|"ports, env, volumes"| Runner
    User -->|"host ports"| FW

    style build fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
    style deploy fill:#1e1e2e,stroke:#a6da95,color:#cdd6f4
```

## Metadata flow per option

### Ports

Ports are the most widely wired option — they flow to **four** destinations.

```mermaid
flowchart LR
    User["oci.containers.my-app.ports<br/>[&quot;8080:8080&quot;, &quot;443:443/udp&quot;]"]

    subgraph oci ["OCI image"]
        Parse["parseContainerPort<br/>&quot;8080:8080&quot; → &quot;8080/tcp&quot;"]
        Exposed["ExposedPorts<br/>{ &quot;8080/tcp&quot; = {}; &quot;443/udp&quot; = {}; }"]
        Parse --> Exposed
    end

    subgraph nixos ["NixOS deploy"]
        Runner["virtualisation.oci-containers<br/>.containers.my-app.ports"]
        FW["networking.firewall<br/>.allowedTCPPorts = [ 8080 443 ]"]
    end

    subgraph hm ["Home-manager deploy"]
        HMRunner["services.podman<br/>.containers.my-app.ports"]
    end

    User --> Parse
    User --> Runner
    User --> FW
    User --> HMRunner

    style oci fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
    style nixos fill:#1e1e2e,stroke:#a6da95,color:#cdd6f4
    style hm fill:#1e1e2e,stroke:#f5c2e7,color:#cdd6f4
```

| Stage | Transformation | File |
|---|---|---|
| User input | `["8080:8080"]` | `_options/ports.nix` |
| OCI ExposedPorts | `mkExposedPorts` → `{ "8080/tcp" = {}; }` | `lib/ports.nix`, `image.nix` |
| NixOS runner | Passed as-is to `virtualisation.oci-containers` | `nixos/run-services.nix` |
| NixOS firewall | Host port extracted via `parseHostPort` → integer | `nixos/run-services.nix` |
| HM runner | Passed as-is to `services.podman.containers` | `home-manager/run-services.nix` |

### Environment

Environment variables are **dual-written** — baked into the OCI image
AND passed to the runner at deploy time.

```mermaid
flowchart LR
    User["oci.containers.my-app.environment<br/>{ RUST_LOG = &quot;info&quot;; }"]

    subgraph oci ["OCI image config"]
        Env["Env = [ &quot;RUST_LOG=info&quot; ]"]
    end

    subgraph runner ["Runner service"]
        NixOS["virtualisation.oci-containers<br/>.containers.my-app.environment"]
        HM["services.podman<br/>.containers.my-app.environment"]
    end

    User -->|"mapAttrsToList<br/>k: v: k=v"| Env
    User -->|"passed as-is"| NixOS
    User -->|"passed as-is"| HM

    style oci fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
    style runner fill:#1e1e2e,stroke:#a6da95,color:#cdd6f4
```

This dual-write means the variable is visible both via `docker inspect`
(from the OCI manifest) and at runtime (from the runner's `--env` flags).

### User and isRoot

The `user` and `isRoot` options control **two things**: the OCI `User`
field and the root filesystem setup (shadow files, home directory).

```mermaid
flowchart TD
    User["oci.containers.my-app.user = &quot;app&quot;<br/>oci.containers.my-app.isRoot = false"]

    subgraph rootfs ["Root filesystem"]
        Shadow["mkShadowSetup<br/>/etc/passwd, /etc/shadow,<br/>/etc/group, home dir"]
    end

    subgraph ociconf ["OCI image config"]
        OCIUser["User = &quot;app&quot;"]
    end

    User --> Shadow
    User --> OCIUser

    style rootfs fill:#1e1e2e,stroke:#f9e2ae,color:#cdd6f4
    style ociconf fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
```

| `isRoot` | OCI `User` | Shadow setup |
|---|---|---|
| `true` | `"root"` | Standard root passwd/group |
| `false` | Value of `user` option | Non-root user with home dir |

### Entrypoint

The entrypoint is auto-derived from `package.meta.mainProgram` when not
set explicitly.

```mermaid
flowchart TD
    User["oci.containers.my-app.entrypoint"]

    Check{entrypoint<br/>explicitly set?}
    Explicit["Use provided list"]
    Auto["Derive from package<br/>meta.mainProgram or pname"]
    Result["OCI config.entrypoint<br/>[&quot;/nix/store/…/bin/hello&quot;]"]

    User --> Check
    Check -->|"Yes"| Explicit
    Check -->|"No"| Auto
    Explicit --> Result
    Auto --> Result

    style Result fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
```

The entrypoint is **only** written to the OCI image config — it is not
forwarded to the runner service (the container runtime reads it from the
image).

### Labels

Labels flow **only** to the OCI image manifest — they are pure metadata
with no deploy-time effect. nix-oci automatically generates labels from
package metadata and container configuration; user-provided labels always
override auto-generated ones.

```mermaid
flowchart TD
    subgraph auto ["Auto-generated (when autoLabels = true)"]
        direction TB
        OCI_STD["OCI standard annotations<br/>org.opencontainers.image.*<br/>(title, version, description,<br/>licenses, base.name, url, authors)"]
        BUILD["Build info<br/>…nix-oci.build.*<br/>(system, optimized-layers,<br/>layer-strategy, reproducible)"]
        HARD["Hardening hints<br/>…nix-oci.hardening.*<br/>(enabled, capabilities, seccomp,<br/>landlock, read-only-rootfs)"]
        K8S["K8s hints<br/>…nix-oci.kubernetes.*<br/>(PSS level, run-as-user/group,<br/>fs-group, seccomp-profile-type)"]
        NET["Network hints<br/>…nix-oci.network.*<br/>(tcp-ports, udp-ports)"]
        NIX["Nix identity<br/>…nix-oci.nix.*<br/>(pname, version,<br/>main-program, dependency-count)"]
        SEC["Nixpkgs security<br/>…nix-oci.security.*<br/>(known-vulnerabilities, insecure,<br/>provenance.source-type)"]
        RT["Runtime info<br/>…nix-oci.runtime.*<br/>(user, is-root)"]
    end

    User["oci.containers.my-app.labels<br/>(user-provided, always wins)"]

    Merged["OCI config.Labels<br/>(auto // user)"]

    OCI_STD --> Merged
    BUILD --> Merged
    HARD --> Merged
    K8S --> Merged
    NET --> Merged
    NIX --> Merged
    SEC --> Merged
    RT --> Merged
    User -->|"overrides"| Merged

    style auto fill:#1e1e2e,stroke:#f9e2ae,color:#cdd6f4
    style Merged fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
```

#### Auto-generated label sources

| Label namespace | Source | Example |
|---|---|---|
| `org.opencontainers.image.title` | `config.name` | `"caddy"` |
| `org.opencontainers.image.version` | `config.tag` or `package.version` | `"2.7.6"` |
| `org.opencontainers.image.description` | `package.meta.description` | `"Fast web server"` |
| `org.opencontainers.image.licenses` | `package.meta.license` (SPDX) | `"Apache-2.0"` |
| `org.opencontainers.image.url` | `package.meta.homepage` | `"https://…"` |
| `org.opencontainers.image.authors` | `package.meta.maintainers` | `"Jane Doe"` |
| `org.opencontainers.image.base.name` | Always `"scratch"` | `"scratch"` |
| `…nix-oci.build.system` | Build platform | `"x86_64-linux"` |
| `…nix-oci.build.optimized-layers` | `optimizeLayers` | `"true"` |
| `…nix-oci.hardening.*` | `hardening` config | various |
| `…nix-oci.kubernetes.pod-security-standard` | Computed from hardening | `"restricted"` |
| `…nix-oci.kubernetes.run-as-user` | `isRoot` (UID 4000 or 0) | `"4000"` |
| `…nix-oci.kubernetes.seccomp-profile-type` | `hardening.seccomp` | `"RuntimeDefault"` |
| `…nix-oci.network.tcp-ports` | `ports` option (parsed) | `"8080,443"` |
| `…nix-oci.nix.pname` | `package.pname` | `"nginx"` |
| `…nix-oci.nix.version` | `package.version` | `"1.27.3"` |
| `…nix-oci.nix.main-program` | `package.meta.mainProgram` | `"nginx"` |
| `…nix-oci.nix.dependency-count` | `builtins.length dependencies` | `"5"` |
| `…nix-oci.security.known-vulnerabilities` | `package.meta.knownVulnerabilities` | `"CVE-…"` |
| `…nix-oci.provenance.source-type` | `package.meta.sourceProvenance` | `"fromSource"` |

To disable auto-labeling, set `autoLabels = false` on the container.
See [Automatic OCI labels](./automatic-labeling.md) for full details.

### Config files

Config file derivations are included in the container root filesystem.
They end up in the **app layer** when `optimizeLayers` is enabled.

```mermaid
flowchart LR
    User["oci.containers.my-app.configFiles<br/>[myNginxConf myAppYaml]"]

    subgraph rootfs ["Root filesystem"]
        Root["mkRoot: included in buildEnv"]
        Optimized["optimized: included in rootPaths<br/>(app layer, after shadowOnly)"]
    end

    User --> Root
    User --> Optimized

    style rootfs fill:#1e1e2e,stroke:#f9e2ae,color:#cdd6f4
```

### Name, tag, and imageRef

```mermaid
flowchart LR
    Name["name<br/>(defaults to attr name)"]
    Tag["tag<br/>(defaults to &quot;latest&quot;)"]
    Ref["imageRef (computed)<br/>&quot;my-app:latest&quot;"]
    Build["nix2container.buildImage<br/>{ name, tag, … }"]
    Runner["Runner service<br/>image = imageRef"]

    Name --> Ref
    Tag --> Ref
    Name --> Build
    Tag --> Build
    Ref --> Runner

    style Ref fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
    style Build fill:#1e1e2e,stroke:#a6da95,color:#cdd6f4
```

`imageRef` is a **readOnly** computed option (`"name:tag"`) used by
the runner service to reference the locally-loaded image.

### Package and dependencies

```mermaid
flowchart TD
    Pkg["package<br/>(e.g. pkgs.hello)"]
    Deps["dependencies<br/>(e.g. [bash coreutils cacert])"]

    subgraph naive ["optimizeLayers = false"]
        Root["mkRoot<br/>single buildEnv with everything"]
        CopyToRoot["buildImage { copyToRoot = [root]; }"]
        Root --> CopyToRoot
    end

    subgraph optimized ["optimizeLayers = true"]
        DepsLayer["mkImageLayers<br/>deps → own layer"]
        AppLayer["rootPaths<br/>shadow + configFiles + package"]
        Fold["foldImageLayers<br/>deduplicates across layers"]
        DepsLayer --> Fold
        AppLayer --> Fold
    end

    Pkg --> Root
    Deps --> Root
    Pkg --> AppLayer
    Deps --> DepsLayer

    style naive fill:#1e1e2e,stroke:#ced4da,color:#cdd6f4
    style optimized fill:#1e1e2e,stroke:#a6da95,color:#cdd6f4
```

### Deploy-only: autoStart and volumes

These options exist **only** in the deploy modules — they have no effect
on the OCI image itself.

```mermaid
flowchart LR
    Auto["autoStart = true"]
    Vols["volumes<br/>[&quot;/data:/data&quot;]"]

    subgraph nixos ["NixOS"]
        NRunner["virtualisation.oci-containers<br/>.containers.my-app"]
        NFW["networking.firewall"]
    end

    subgraph hm ["Home-manager"]
        HRunner["services.podman<br/>.containers.my-app"]
    end

    Auto -->|"gates runner creation"| NRunner
    Auto -->|"gates runner creation"| HRunner
    Auto -->|"gates firewall rules"| NFW
    Vols --> NRunner
    Vols --> HRunner

    style nixos fill:#1e1e2e,stroke:#a6da95,color:#cdd6f4
    style hm fill:#1e1e2e,stroke:#f5c2e7,color:#cdd6f4
```

When `autoStart = false`, only the loader service is created — no runner,
no firewall rules, no volumes. The image is loaded but not started.

## Service dependency chain

Both NixOS and home-manager wire a strict ordering between the loader
and runner services. When a healthcheck is present and the backend is
Podman, the runner uses `Type=notify` with `--sdnotify=healthy` — systemd
waits for the healthcheck to pass before considering the service ready.

```mermaid
sequenceDiagram
    participant systemd
    participant Loader as oci-load-my-app
    participant Runner as podman-my-app
    participant HC as Healthcheck

    systemd->>Loader: Start (oneshot)
    Loader->>Loader: skopeo copy nix:image → runtime
    Loader-->>systemd: ExitCode=0, RemainAfterExit
    systemd->>Runner: Start (After + Requires loader)
    Runner->>Runner: podman run --sdnotify=healthy
    Note over Runner: Service status: "starting"
    loop Every healthcheck.interval
        Runner->>HC: Execute healthcheck command
        HC-->>Runner: exit code
    end
    HC-->>Runner: First success (exit 0)
    Runner-->>systemd: sd_notify(READY=1)
    Note over systemd: Service status: "active"
```

| Platform | Loader | Runner | Dependency | Health-aware |
|---|---|---|---|---|
| NixOS (Podman) | `systemd.services.oci-load-<name>` | `systemd.services.podman-<name>` | `After` + `Requires` | `--sdnotify=healthy` + `Type=notify` |
| NixOS (Docker) | `systemd.services.oci-load-<name>` | `systemd.services.docker-<name>` | `After` + `Requires` | Healthcheck in image only |
| Home-manager | `systemd.user.services.oci-load-<name>` | Podman quadlet | `extraConfig.Unit` | Quadlet `Notify=healthy` + `Type=notify` |

## Complete wiring summary

```mermaid
flowchart TD
    subgraph user ["User-facing options"]
        pkg[package]
        deps[dependencies]
        ep[entrypoint]
        usr[user / isRoot]
        ports[ports]
        env[environment]
        labels[labels]
        cfg[configFiles]
        hc[healthcheck]
        ss[stopSignal]
        wd[workingDir]
        dv[declaredVolumes]
        nm[name / tag]
        auto[autoStart]
        vols[volumes]
        hard[hardening]
    end

    subgraph autolabels ["Auto-generated labels"]
        ociStd["org.opencontainers.image.*"]
        buildMeta["…nix-oci.build.*"]
        hardLabels["…nix-oci.hardening.*"]
        k8sLabels["…nix-oci.kubernetes.*<br/>(PSS, SecurityContext)"]
        netLabels["…nix-oci.network.*"]
        nixLabels["…nix-oci.nix.*"]
        secLabels["…nix-oci.security.*"]
    end

    subgraph oci ["OCI image config"]
        oEP[config.entrypoint]
        oUser[config.User]
        oExposed[config.ExposedPorts]
        oEnv[config.Env]
        oLabels[config.Labels]
        oHC[config.Healthcheck]
        oSS[config.StopSignal]
        oWD[config.WorkingDir]
        oVols[config.Volumes]
    end

    subgraph rootfs ["Root filesystem / layers"]
        root[mkRoot / rootPaths]
        shadow[mkShadowSetup]
        layers[mkImageLayers]
    end

    subgraph services ["Deploy services"]
        loader[oci-load-&lt;name&gt;]
        runner[runner service<br/>+ sdnotify=healthy]
        fw[NixOS firewall]
    end

    ep --> oEP
    usr --> oUser
    usr --> shadow
    ports --> oExposed
    ports --> runner
    ports --> fw
    env --> oEnv
    env --> runner
    pkg -.->|"meta.*"| ociStd
    pkg -.->|"pname, version"| nixLabels
    pkg -.->|"knownVulns"| secLabels
    nm -.->|"name, tag"| ociStd
    hard -.-> hardLabels
    hard -.-> k8sLabels
    usr -.-> k8sLabels
    ports -.->|"parsed"| netLabels
    deps -.->|"count"| nixLabels
    ociStd --> oLabels
    buildMeta --> oLabels
    hardLabels --> oLabels
    k8sLabels --> oLabels
    netLabels --> oLabels
    nixLabels --> oLabels
    secLabels --> oLabels
    labels -->|"overrides"| oLabels
    hc --> oHC
    hc -->|"sdnotify=healthy<br/>Type=notify"| runner
    ss --> oSS
    wd --> oWD
    dv --> oVols
    cfg --> root
    pkg --> root
    deps --> layers
    nm --> loader
    nm --> runner
    auto --> runner
    vols --> runner
    shadow --> root

    style user fill:#1e1e2e,stroke:#cdd6f4,color:#cdd6f4
    style autolabels fill:#1e1e2e,stroke:#f5c2e7,color:#cdd6f4
    style oci fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
    style rootfs fill:#1e1e2e,stroke:#f9e2ae,color:#cdd6f4
    style services fill:#1e1e2e,stroke:#a6da95,color:#cdd6f4
```

## Healthcheck

Healthchecks are the most deeply wired option — they flow from the NixOS
module configuration through the OCI image manifest into systemd service
readiness.

### Automatic derivation from NixOS services

When using `nixosConfig` with a `mainService`, service adapters
**automatically derive** the healthcheck command from the NixOS module
configuration. No manual healthcheck setup is required.

```mermaid
flowchart TD
    NixOS["NixOS module config<br/>(services.nginx, services.postgresql, …)"]

    subgraph adapter ["Service adapter"]
        Scan["Introspect service config<br/>(ports, endpoints, SSL, bind)"]
        Derive["Auto-derive healthcheck command"]
        Scan --> Derive
    end

    subgraph oci ["OCI image"]
        HC["config.Healthcheck<br/>Test = [CMD curl -f http://…]<br/>Interval / Timeout / Retries"]
    end

    subgraph systemd ["Deploy: systemd"]
        SDNotify["--sdnotify=healthy<br/>(Podman only)"]
        Type["Type=notify<br/>NotifyAccess=all"]
        Ready["READY=1 sent when<br/>healthcheck first passes"]
        SDNotify --> Ready
        Type --> Ready
    end

    NixOS --> Scan
    Derive --> HC
    HC --> SDNotify

    style adapter fill:#1e1e2e,stroke:#f9e2ae,color:#cdd6f4
    style oci fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
    style systemd fill:#1e1e2e,stroke:#a6da95,color:#cdd6f4
```

| Service | NixOS options introspected | Derived healthcheck |
|---|---|---|
| **nginx** | `virtualHosts.*.listen[].{port, ssl}`, locations (scans for `/health`, `/healthz`, `stub_status`), `onlySSL`/`forceSSL` | `curl -f http[s]://localhost:${port}${bestPath}` |
| **PostgreSQL** | `settings.port` (default 5432), `package` | `pg_isready -h localhost -p ${port}` |
| **Redis** | `servers.<name>.port`, `servers.<name>.bind` | `redis-cli -h ${bind} -p ${port} ping` |

### Explicit healthcheck (non-NixOS containers)

```nix
oci.containers.my-app = {
  package = pkgs.myApp;
  dependencies = [ pkgs.curl ];
  healthcheck = {
    command = [ "${pkgs.curl}/bin/curl" "-f" "http://localhost:8080/health" ];
    interval = 15;   # seconds
    timeout = 3;
    startPeriod = 5;
    retries = 3;
  };
};
```

### Systemd integration (deploy)

When a container has a healthcheck and the backend is Podman, the deploy
modules wire `--sdnotify=healthy` into the runner service:

| Platform | Mechanism | Effect |
|---|---|---|
| **NixOS (Podman)** | `extraOptions = ["--sdnotify=healthy"]` + `Type=notify` | systemd waits for healthcheck to pass |
| **Home-manager** | Quadlet `Notify=healthy` + `Type=notify` | systemd waits for healthcheck to pass |
| **Docker** | Healthcheck in image only | No systemd integration |

| Stage | Transformation | File |
|---|---|---|
| User/adapter input | `healthcheck.command = [...]` | `_options/healthcheck.nix` or service adapter |
| OCI image | `config.Healthcheck.Test = ["CMD"] ++ command` | `image.nix`, `mkSimpleOCI.nix`, `mkNixOCI.nix` |
| NixOS runner | `--sdnotify=healthy` + `Type=notify` | `nixos/run-services.nix` |
| HM runner | Quadlet `Notify=healthy` + `Type=notify` | `home-manager/run-services.nix` |

## StopSignal

The stop signal tells the container runtime which signal to send for
**graceful shutdown**. Different services need different signals — using
the wrong one can cause data loss or abrupt termination.

```mermaid
flowchart LR
    subgraph sources ["Signal source (priority order)"]
        Explicit["Explicit option<br/>stopSignal = &quot;SIGQUIT&quot;"]
        Adapter["Service adapter<br/>(nginx → SIGQUIT,<br/>PostgreSQL → SIGINT)"]
        Systemd["systemd KillSignal<br/>(from NixOS service)"]
    end

    OCI["OCI config.StopSignal"]

    Explicit --> OCI
    Adapter --> OCI
    Systemd --> OCI

    style sources fill:#1e1e2e,stroke:#f9e2ae,color:#cdd6f4
    style OCI fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
```

### Auto-derived signals per service

| Service | Signal | Why |
|---|---|---|
| **nginx** | `SIGQUIT` | Graceful worker shutdown — finish serving current requests before exit |
| **PostgreSQL** | `SIGINT` | Fast shutdown — rollback active transactions, clean exit. `SIGQUIT` (smart shutdown) can hang waiting for clients to disconnect |
| **Redis** | `SIGTERM` | Save dataset (if configured) and exit gracefully |
| *(default)* | `SIGTERM` | Container runtime default when not specified |

Service adapters use `lib.mkDefault`, so the user can always override.
When no adapter sets a signal, the `extractServiceData` function checks
the systemd `KillSignal` from the NixOS service config.

| Stage | Transformation | File |
|---|---|---|
| Service adapter | `oci.container.stopSignal = "SIGQUIT"` | `service-adapters/nginx.nix` etc. |
| systemd fallback | `serviceConfig.KillSignal` | `entrypoint.nix` (`extractServiceData`) |
| OCI image | `config.StopSignal = "SIGQUIT"` | `image.nix`, `mkSimpleOCI.nix`, `mkNixOCI.nix` |

## WorkingDir

The working directory sets the initial `$PWD` for the container process.

```mermaid
flowchart TD
    subgraph sources ["WorkingDir source (priority order)"]
        Explicit["Explicit option<br/>workingDir = &quot;/app&quot;"]
        Systemd["systemd WorkingDirectory"]
        DataDir["services.&lt;name&gt;.dataDir<br/>(e.g. /var/lib/postgresql)"]
        Home["User home directory<br/>(/root or /home/&lt;user&gt;)"]
    end

    OCI["OCI config.WorkingDir"]

    Explicit -->|"1st"| OCI
    Systemd -->|"2nd"| OCI
    DataDir -->|"3rd"| OCI
    Home -->|"4th"| OCI

    style sources fill:#1e1e2e,stroke:#f9e2ae,color:#cdd6f4
    style OCI fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
```

### Auto-derivation chain (NixOS containers)

For NixOS containers, the working directory is resolved in priority order:

1. **Explicit** `oci.container.workingDir` (user override)
2. **systemd** `WorkingDirectory` from the service config
3. **NixOS service** `dataDir` (e.g., PostgreSQL → `/var/lib/postgresql`)
4. **User home** directory (`/root` or `/home/<user>`)

This means PostgreSQL containers automatically get `WorkingDir = /var/lib/postgresql`
without any manual configuration.

For non-NixOS containers, `workingDir` defaults to `null` (runtime default,
typically `/`). Set it explicitly when needed.

| Stage | Transformation | File |
|---|---|---|
| NixOS auto-derive | systemd → dataDir → home | `entrypoint.nix` (`_output.workingDir`) |
| Explicit option | `workingDir = "/app"` | `_options/working-dir.nix` |
| OCI image | `config.WorkingDir = "/var/lib/postgresql"` | `image.nix`, `mkSimpleOCI.nix`, `mkNixOCI.nix` |

## Declared volumes

OCI `Volumes` declares paths in the image that contain **persistent data**.
This is image-level metadata — it tells the container runtime which paths
should be treated as named volumes (surviving container restarts).

This is **separate from** deploy-time `volumes` (host bind mounts like
`"/data:/data"` passed to the runner service).

```mermaid
flowchart TD
    subgraph nixos ["NixOS auto-derivation"]
        State["StateDirectory<br/>→ /var/lib/&lt;dir&gt;"]
        Runtime["RuntimeDirectory<br/>→ /run/&lt;dir&gt;"]
        Cache["CacheDirectory<br/>→ /var/cache/&lt;dir&gt;"]
        Logs["LogsDirectory<br/>→ /var/log/&lt;dir&gt;"]
    end

    subgraph explicit ["Explicit"]
        User["declaredVolumes =<br/>[&quot;/data&quot; &quot;/var/lib/app&quot;]"]
    end

    OCI["OCI config.Volumes<br/>{ &quot;/var/lib/postgresql&quot;: {},<br/>&quot;/run/postgresql&quot;: {} }"]

    State --> OCI
    Runtime --> OCI
    Cache --> OCI
    Logs --> OCI
    User --> OCI

    style nixos fill:#1e1e2e,stroke:#f9e2ae,color:#cdd6f4
    style explicit fill:#1e1e2e,stroke:#cdd6f4,color:#cdd6f4
    style OCI fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
```

### Auto-derivation from systemd directories

The `extractServiceData` function reads the systemd service config and
translates directory declarations into OCI volume paths:

| systemd field | OCI Volume path |
|---|---|
| `StateDirectory = "postgresql"` | `/var/lib/postgresql` |
| `RuntimeDirectory = "nginx"` | `/run/nginx` |
| `CacheDirectory = "nginx"` | `/var/cache/nginx` |
| `LogsDirectory = "nginx"` | `/var/log/nginx` |

Explicit `declaredVolumes` are merged with auto-derived ones.

### Declared volumes vs deploy volumes

| | `declaredVolumes` | `volumes` |
|---|---|---|
| **What** | OCI metadata in image manifest | Host bind mounts at runtime |
| **Where** | `config.Volumes` in image | `podman run -v` / `docker run -v` |
| **Purpose** | Tells runtime "this path has persistent data" | Maps host paths into container |
| **Auto-derived** | Yes (from systemd dirs) | No (user-specified) |
| **File** | `_options/declared-volumes.nix` | `deploy/_containers/volumes.nix` |

| Stage | Transformation | File |
|---|---|---|
| NixOS auto-derive | systemd dirs → path list | `entrypoint.nix` (`_output.declaredVolumes`) |
| Explicit option | `declaredVolumes = ["/data"]` | `_options/declared-volumes.nix` |
| OCI image | `config.Volumes = { "/var/lib/postgresql" = {}; }` | `image.nix`, `mkSimpleOCI.nix`, `mkNixOCI.nix` |
