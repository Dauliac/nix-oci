+++
title = "Validation-gated delivery"
description = "How nix-oci enforces that every image is validated before it can be loaded or published — probes, checks, and signing as prerequisites, never afterthoughts"
+++

# Validation-gated delivery

nix-oci enforces a simple rule: **no image leaves your machine without
passing validation.** Probes and checks are not optional post-hoc steps —
they are prerequisites wired into the build and delivery pipeline.

- You cannot **build** the image package without pure checks passing (build-time gate)
- You cannot **push** or **load** the image without the gate passing first
- All validation is expressed as Nix derivations — hermetic, cached, parallel

## Flake outputs per container

Each container produces exactly 5 outputs:

```mermaid
flowchart LR
    subgraph outputs ["Flake outputs for oci.containers.myapp"]
        direction TB
        pkg["packages.oci-myapp<br/><b>Gated image</b><br/><i>building forces all checks</i>"]
        sandbox["apps.oci-sandbox-myapp<br/><i>bubblewrap shell</i>"]
        push["apps.oci-push-myapp<br/><i>skopeo copy nix: →<br/>docker://registry</i>"]
        docker["apps.oci-load-docker-myapp<br/><i>skopeo copy nix: →<br/>docker-daemon:</i>"]
        podman["apps.oci-load-podman-myapp<br/><i>skopeo copy nix: →<br/>containers-storage:</i>"]
    end

    classDef pkgStyle fill:#2ecc71,color:#fff,stroke:#27ae60,stroke-width:2px
    classDef appStyle fill:#3498db,color:#fff,stroke:#2980b9

    class pkg pkgStyle
    class sandbox,push,docker,podman appStyle
```

| Output | Purpose |
|---|---|
| `packages.oci-myapp` | Gated OCI image — building it forces all checks to pass |
| `apps.oci-sandbox-myapp` | Run the container filesystem in a bubblewrap sandbox |
| `apps.oci-push-myapp` | Push to registry via `skopeo copy nix: → docker://` (streams, no archive) |
| `apps.oci-load-docker-myapp` | Load into Docker via `skopeo copy nix: → docker-daemon:` |
| `apps.oci-load-podman-myapp` | Load into Podman via `skopeo copy nix: → containers-storage:` |

Every app references the gate — Nix will build all checks before
the app script can execute.

## Full pipeline

```mermaid
flowchart TB
    subgraph eval ["nix eval (module system)"]
        config["Container config<br/><i>NixOS modules</i>"]
    end

    subgraph build ["nix build (parallel derivations)"]
        direction TB
        config --> mkOCI["mkOCI()<br/><i>OCI image manifest</i><br/><i>JSON ~KB, references store paths</i><br/><i>conforms to OCI Image Spec</i>"]

        mkOCI --> pure_checks
        mkOCI --> archive["mkTransientArchive<br/><i>created inside sandbox</i><br/><i>never in nix store</i>"]

        subgraph pure_checks ["Pure checks (parallel derivations)"]
            direction LR
            conftest["conftest<br/><i>OPA/Rego policies</i>"]
            dockle["dockle<br/><i>OCI best practices</i>"]
            dive["dive<br/><i>layer efficiency</i>"]
            sbom["syft<br/><i>SBOM (CycloneDX)</i>"]
            credleak["trivy<br/><i>secret patterns</i>"]
        end

        archive -.->|"transient tar"| pure_checks

        pure_checks --> gate["GATE<br/><i>nativeBuildInputs = all stamps</i><br/><i>touch $out</i>"]
        gate --> package["packages.oci-myapp<br/><b>Gated image</b>"]
    end

    subgraph delivery ["Delivery (self-contained shell scripts)"]
        direction LR
        package --> sandbox["oci-sandbox-myapp<br/><i>bubblewrap</i>"]
        package --> push["oci-push-myapp<br/><i>skopeo copy nix: →<br/>docker://registry</i>"]
        package --> load_d["oci-load-docker-myapp<br/><i>skopeo copy nix: →<br/>docker-daemon:</i>"]
        package --> load_p["oci-load-podman-myapp<br/><i>skopeo copy nix: →<br/>containers-storage:</i>"]
    end

    classDef gateStyle fill:#e74c3c,color:#fff,stroke:#c0392b,stroke-width:2px
    classDef buildStyle fill:#2ecc71,color:#fff,stroke:#27ae60
    classDef deliveryStyle fill:#3498db,color:#fff,stroke:#2980b9
    classDef transientStyle fill:#f39c12,color:#fff,stroke:#e67e22

    class gate gateStyle
    class conftest,dockle,dive,sbom,credleak buildStyle
    class sandbox,push,load_d,load_p deliveryStyle
    class archive transientStyle
```

## OCI transport model

All delivery apps use the
[OCI Distribution Specification](https://github.com/opencontainers/distribution-spec)
transports via [Skopeo](https://github.com/containers/skopeo).
No intermediate archive is ever written to disk:

```mermaid
flowchart LR
    nix_store["Nix store<br/><i>image JSON ~KB</i><br/><i>app deps (already there)</i><br/><i>stamp files ~0B</i>"]

    nix_store -->|"nix: transport<br/>(streams layers)"| docker_daemon["docker-daemon:<br/><i>Docker Engine API</i>"]
    nix_store -->|"nix: transport<br/>(streams layers)"| containers["containers-storage:<br/><i>Podman / CRI-O</i>"]
    nix_store -->|"nix: transport<br/>(streams layers)"| registry["docker://registry<br/><i>OCI Distribution API</i>"]
    nix_store -->|"mkTransientArchive<br/>(inside sandbox only)"| checks["Pure checks<br/><i>scan tar → rm → touch $out</i>"]

    classDef transportStyle fill:#3498db,color:#fff,stroke:#2980b9
    classDef transientStyle fill:#f39c12,color:#fff,stroke:#e67e22

    class docker_daemon,containers,registry transportStyle
    class checks transientStyle
```

| Transport | OCI spec | Used by |
|---|---|---|
| `nix:` → `docker://` | [Distribution Spec](https://github.com/opencontainers/distribution-spec) push API | `oci-push-*` |
| `nix:` → `docker-daemon:` | Docker Engine API (local) | `oci-load-docker-*` |
| `nix:` → `containers-storage:` | containers/storage library | `oci-load-podman-*` |
| `mkTransientArchive` | [Image Layout](https://github.com/opencontainers/image-spec/blob/main/image-layout.md) (ephemeral) | Pure checks only |

Every arrow streams or creates transient data. No tarball ever lands
in the Nix store.

## Backend toggle

Probes (amicontained, CDK, DEEPCE, linPEAS) can run as **build-time
VM checks** (derivations, in the gate) or at runtime. A single toggle
controls the routing:

```mermaid
flowchart LR
    spec["Pipeline step<br/><i>phase, category, backend</i><br/><i>mkStamp, mkScript</i>"]

    spec -->|"backend = pure/vm"| stamp["mkStamp derivation<br/><i>→ gate nativeBuildInputs</i>"]
    spec -->|"backend = daemon"| script["mkScript package<br/><i>→ available as app</i>"]

    toggle["oci.pipeline.defaultBackend<br/><i>global: vm | daemon</i>"]
    override["per-step override<br/><i>step.backend = daemon</i>"]

    toggle -.-> spec
    override -.-> spec

    classDef specStyle fill:#9b59b6,color:#fff,stroke:#8e44ad,stroke-width:2px
    class spec specStyle
```

```nix
# Global default — all probes in the build-time gate
oci.pipeline.defaultBackend = "vm";
```

| Scenario | Gate (build-time) | Available as app |
|---|---|---|
| `defaultBackend = "vm"` | all probes + pure checks | none |
| `defaultBackend = "daemon"` | pure checks only | all probes |

## Step registry (extensibility)

Tools register themselves into `oci.pipeline.steps` — the pipeline
composer reads what is registered. This is dependency inversion via
the NixOS module system:

```mermaid
flowchart TB
    subgraph registry ["oci.pipeline.steps (open registry)"]
        direction LR
        subgraph builtin ["Built-in (19 steps)"]
            direction TB
            pure_s["conftest, dockle, dive<br/>syft, credentials-leak"]
            probe_s["amicontained, cdk<br/>deepce, linpeas, cst, dgoss"]
            post_s["cve-trivy, cve-grype<br/>cosign-sign, compliance-trivy"]
        end
        subgraph external ["External (user-contributed)"]
            notation_s["notation-sign"]
            custom_s["my-org-compliance"]
        end
    end

    registry --> composer["Pipeline composer<br/><i>reads all steps</i><br/><i>filters enabled per container</i><br/><i>resolves backends</i>"]

    composer --> gate_out["Gate derivation<br/><i>pure + vm stamps</i>"]
    composer --> apps_out["4 apps per container<br/><i>sandbox, push,<br/>load-docker, load-podman</i>"]

    classDef registryStyle fill:#1abc9c,color:#fff,stroke:#16a085,stroke-width:2px
    class registry registryStyle
```

Adding a new tool requires **zero changes to nix-oci**:

```nix
# In your flake.nix
perSystem = { config, pkgs, ... }: {
  oci.pipeline.steps.notation-sign = {
    phase = "post-push";
    category = "signing";
    deps = [ "push" ];
    isEnabled = c: c.signing.notation.enabled or false;
    mkScript = { containerId, perSystemConfig }:
      pkgs.writeShellScriptBin "notation-sign" ''
        REGISTRY="''${NIX_OCI_REGISTRY}"
        REF="$REGISTRY/${containerId}:latest"
        DIGEST=$(skopeo inspect --format '{{.Digest}}' "docker://$REF")
        notation sign "$REF@$DIGEST" --key "$NOTATION_KEY"
      '';
    timeout = 60;
  };
};
```

### Step spec

Each step declares:

| Field | Type | Purpose |
|---|---|---|
| `phase` | `"build-check"` / `"probe"` / `"post-push"` | Pipeline phase |
| `category` | `"policy"` / `"cve"` / `"lint"` / ... | For docs and grouping |
| `backend` | `"pure"` / `"vm"` / `"daemon"` / `null` | Override or infer from phase |
| `isEnabled` | `containerConfig → bool` | Per-container activation |
| `mkStamp` | `{ containerId, perSystemConfig } → derivation` | Build-time gate stamp |
| `mkScript` | `{ containerId, perSystemConfig } → package` | Runtime script |
| `timeout` | `int` | Seconds |

## What is pure vs. what needs network

Not all tools are equal. The build-time gate only includes tools that
are truly **offline** — no database downloads, no network access:

| Tool | Pure? | Why |
|---|---|---|
| conftest | Yes | Runs OPA/Rego policies (Nix store paths) against image JSON |
| dockle | Yes | Lints with built-in rules |
| dive | Yes | Analyzes layer efficiency from tar |
| syft | Yes | Generates SBOM from file patterns — no vuln DB |
| trivy (secret scan) | Yes | Built-in regex patterns for credentials |
| trivy (CVE) | No | Needs vulnerability database download |
| grype (CVE) | No | Needs vulnerability database download |
| trivy (compliance) | No | Scans from registry |
| cosign | No | Needs registry digest |

CVE scanners and signing are `phase = "post-push"` — they run outside
the Nix sandbox, after the image is in a registry.

## Nothing stored beyond what Nix already has

nix2container produces an
[OCI Image Manifest](https://github.com/opencontainers/image-spec/blob/main/manifest.md)
as JSON (~KB) referencing existing Nix store paths. No layers, no archives
are stored:

```
IN STORE:                              NEVER IN STORE:
+-- OCI image manifest JSON (~KB)      +-- compressed layers
+-- app dependencies (already there)   +-- assembled docker archives
+-- stamp files (touch $out, ~0B)      +-- tarballs of any kind
```

## Environment variables

All pipeline env vars use the `NIX_OCI_*` prefix:

| Variable | Purpose |
|---|---|
| `NIX_OCI_REGISTRY` | Override target registry |
| `NIX_OCI_PUSHED_TAG` | Stdout marker for pushed tags |
| `NIX_OCI_REPORT_DIR` | Directory for tool reports (SBOM, scan results) |

## Further reading

- [OCI Image Format Specification](https://github.com/opencontainers/image-spec)
- [OCI Distribution Specification](https://github.com/opencontainers/distribution-spec)
- [Archive-less container building](archive-less-container-building.html)
  — how nix2container avoids tar archives
- [OCI standards compliance](oci-standards-compliance.html)
  — layers, media types, image configuration
