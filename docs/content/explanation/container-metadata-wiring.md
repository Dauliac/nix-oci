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
        OCI["OCI image config<br/>(entrypoint, User, Env,<br/>ExposedPorts, Labels)"]
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
with no deploy-time effect.

```mermaid
flowchart LR
    User["oci.containers.my-app.labels<br/>{ &quot;org.opencontainers.image.source&quot;<br/>= &quot;https://github.com/…&quot;; }"]
    OCI["OCI config.Labels"]

    User -->|"passed as-is"| OCI

    style OCI fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
```

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
and runner services.

```mermaid
sequenceDiagram
    participant systemd
    participant Loader as oci-load-my-app
    participant Runner as podman-my-app / docker-my-app

    systemd->>Loader: Start (oneshot)
    Loader->>Loader: skopeo copy nix:image → runtime
    Loader-->>systemd: ExitCode=0, RemainAfterExit
    systemd->>Runner: Start (After + Requires loader)
    Runner->>Runner: podman/docker run my-app:latest
```

| Platform | Loader | Runner | Dependency mechanism |
|---|---|---|---|
| NixOS | `systemd.services.oci-load-<name>` | `systemd.services.<backend>-<name>` | `After` + `Requires` on runner |
| Home-manager | `systemd.user.services.oci-load-<name>` | Podman quadlet | `extraConfig.Unit.After` + `Requires` |

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
        nm[name / tag]
        auto[autoStart]
        vols[volumes]
    end

    subgraph oci ["OCI image config"]
        oEP[config.entrypoint]
        oUser[config.User]
        oExposed[config.ExposedPorts]
        oEnv[config.Env]
        oLabels[config.Labels]
    end

    subgraph rootfs ["Root filesystem / layers"]
        root[mkRoot / rootPaths]
        shadow[mkShadowSetup]
        layers[mkImageLayers]
    end

    subgraph services ["Deploy services"]
        loader[oci-load-&lt;name&gt;]
        runner[runner service]
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
    labels --> oLabels
    cfg --> root
    pkg --> root
    deps --> layers
    nm --> loader
    nm --> runner
    auto --> runner
    vols --> runner
    shadow --> root

    style user fill:#1e1e2e,stroke:#cdd6f4,color:#cdd6f4
    style oci fill:#1e1e2e,stroke:#89b4fa,color:#cdd6f4
    style rootfs fill:#1e1e2e,stroke:#f9e2ae,color:#cdd6f4
    style services fill:#1e1e2e,stroke:#a6da95,color:#cdd6f4
```

## Note on healthcheck

nix-oci does **not** currently provide a `healthcheck` option. OCI
healthchecks can be configured at the container runtime level (e.g. via
NixOS `virtualisation.oci-containers` options or Podman quadlet config)
but are not wired through the nix-oci module system.
