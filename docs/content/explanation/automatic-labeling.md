+++
title = "Automatic OCI labels"
description = "How nix-oci auto-generates OCI standard annotations, build metadata, hardening hints, and Kubernetes Pod Security Standard levels from container configuration"
+++

# Automatic OCI labels

Every container image built by nix-oci is automatically annotated with
standardised OCI labels derived from package metadata, build context,
and security configuration. User-provided labels always override
auto-generated ones.

All auto-generated labels are **deterministic**: no timestamps, no
impure inputs, and they preserve bit-for-bit reproducibility.

Set [`autoLabels`](../reference/flake-parts-options.html) to `false` on any container to disable all auto-generation.

## OCI standard annotations

nix-oci populates the [`org.opencontainers.image.*`](https://specs.opencontainers.org/image-spec/annotations/)
namespace from data already present in the Nix package:

| OCI annotation | Nix source | Example |
|---|---|---|
| `title` | `config.name` (container attr name) | `"caddy"` |
| `version` | `config.tag` or `package.version` | `"2.7.6"` |
| `description` | `package.meta.description` | `"Fast web server"` |
| `licenses` | `package.meta.license` (SPDX expression) | `"Apache-2.0"` |
| `url` | `package.meta.homepage` | `"https://caddyserver.com"` |
| `authors` | `package.meta.maintainers` (name or GitHub handle) | `"Jane Doe, jdoe"` |
| `documentation` | `package.meta.changelog` | `"https://…/CHANGELOG.md"` |
| `base.name` | Always `"scratch"` (distroless by construction) | `"scratch"` |

Container registries,
security scanners ([Trivy](https://trivy.dev/),
[Grype](https://github.com/anchore/grype),
[Snyk](https://snyk.io/blog/how-and-when-to-use-docker-labels-oci-container-annotations/)),
and Kubernetes admission controllers consume these standard annotations.

### Labels not auto-generated

Some OCI annotations require user input or would break reproducibility:

| Annotation | Why not auto-generated |
|---|---|
| `source` | Requires flake `self.rev` threading; set via `labels` |
| `revision` | Same; set via `labels` |
| `created` | Timestamps break bit-for-bit reproducibility |
| `vendor` | Not derivable from package metadata |

## Build metadata

Labels under `io.github.dauliac.nix-oci.build.*` record how nix-oci
constructed the image:

| Label | Value | Source |
|---|---|---|
| `build.system` | `"x86_64-linux"` | Build platform |
| `build.optimized-layers` | `"true"` / `"false"` | `optimizeLayers` option |
| `build.layer-strategy` | `"fine-grained"` / `"minimal"` | `layerStrategy` option |
| `build.reproducible` | `"true"` | Always (nix-oci guarantee) |

## Runtime info

| Label | Value | Source |
|---|---|---|
| `runtime.user` | `"root"` / `"non-root"` | `isRoot` option |
| `runtime.is-root` | `"true"` / `"false"` | `isRoot` option |

## Hardening labels

When `hardening.enable = true`, labels under
`io.github.dauliac.nix-oci.hardening.*` describe the container's
security posture:

| Label | Example value |
|---|---|
| `hardening.enabled` | `"true"` |
| `hardening.no-new-privileges` | `"true"` |
| `hardening.read-only-rootfs` | `"true"` |
| `hardening.capabilities-drop` | `"ALL"` |
| `hardening.capabilities-add` | `"NET_BIND_SERVICE"` |
| `hardening.seccomp-profile` | `"strict"` / `"moderate"` / `"web-server"` |
| `hardening.landlock-enabled` | `"true"` |
| `hardening.dns-disabled` | `"true"` |
| `hardening.tls-trust-store-removed` | `"true"` |

Deploy modules read these labels and translate them to container runtime
flags (`--security-opt`, `--cap-drop`, `--cap-add`, `--read-only`).

## Kubernetes Pod Security Standard level

nix-oci computes a **Kubernetes Pod Security Standard level** from the
hardening configuration and embeds it as:

```
io.github.dauliac.nix-oci.kubernetes.pod-security-standard = "restricted"
```

| PSS level | Required configuration |
|---|---|
| **restricted** | `!isRoot` + `noNewPrivileges` + `capabilities.drop = ["ALL"]` + `seccomp.enable` + `readOnlyRootfs` |
| **baseline** | `hardening.enable = true` (some restrictions) |
| **privileged** | No hardening |

### Kyverno and OPA/Gatekeeper integration

Kubernetes admission controllers can read OCI image labels at admission
time via [Kyverno's `imageData`](https://kyverno.io/docs/policy-types/cluster-policy/variables/)
context (`imageData.configData.config.Labels`) and use them to:

- **Validate**: reject images that don't meet a minimum PSS level
- **Mutate**: auto-generate `securityContext` from the image's declared
  security posture (a growing pattern in 2026: "secure by default" via
  mutation rather than manual YAML)
- **Annotate**: add pod annotations from image metadata

Example Kyverno policy sketch:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-restricted-pss
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-pss-label
      match:
        any:
          - resources:
              kinds: ["Pod"]
      context:
        - name: imageData
          imageRegistry:
            reference: "{{ element.image }}"
      validate:
        message: "Image must declare PSS level 'restricted'"
        deny:
          conditions:
            - key: "{{ imageData.configData.config.Labels.\"io.github.dauliac.nix-oci.kubernetes.pod-security-standard\" }}"
              operator: NotEquals
              value: "restricted"
```

## Kubernetes SecurityContext hints

Beyond the PSS level, nix-oci embeds the exact values needed to
populate a Kubernetes `securityContext`. Kyverno mutation policies can
read these and auto-generate the SecurityContext, with no manual YAML needed.

| Label | Value | K8s field |
|---|---|---|
| `kubernetes.run-as-user` | `"4000"` (non-root) or `"0"` | `runAsUser` |
| `kubernetes.run-as-group` | `"4000"` or `"0"` | `runAsGroup` |
| `kubernetes.fs-group` | `"4000"` or `"0"` | `fsGroup` |
| `kubernetes.seccomp-profile-type` | `"RuntimeDefault"` | `seccompProfile.type` |

The seccomp label is only set when `hardening.seccomp.enable = true`.

## Network hints

nix-oci parses port declarations and surfaces them as labels for
**NetworkPolicy generation**:

| Label | Example | Source |
|---|---|---|
| `network.tcp-ports` | `"8080,443"` | `ports` option (TCP entries) |
| `network.udp-ports` | `"53"` | `ports` option (UDP entries) |

Kyverno can read these to auto-generate `NetworkPolicy` ingress rules --
single source of truth from the Nix declaration to the K8s network
policy.

## Nix package identity

| Label | Example | Source |
|---|---|---|
| `nix.pname` | `"nginx"` | `package.pname` |
| `nix.version` | `"1.27.3"` | `package.version` |
| `nix.main-program` | `"nginx"` | `package.meta.mainProgram` |
| `nix.dependency-count` | `"5"` | `builtins.length dependencies` |

These let fleet operators trace images back to exact Nix packages,
even when the OCI name or tag has been overridden.

## Nixpkgs security metadata

nixpkgs carries security fields that nix-oci surfaces as labels:

| Label | Example | Source |
|---|---|---|
| `security.known-vulnerabilities` | `"CVE-2024-1234,CVE-2024-5678"` | `package.meta.knownVulnerabilities` |
| `security.insecure` | `"true"` | Set when `knownVulnerabilities` is non-empty |
| `provenance.source-type` | `"fromSource"` | `package.meta.sourceProvenance` |

The `provenance.source-type` label indicates whether someone
built the package from source (`fromSource`), distributed it as a pre-built binary
(`binaryNativeCode`), or compiled it to bytecode (`bytecode`). This is valuable for
supply chain audits; Kyverno can reject images containing pre-built
binaries from untrusted sources.

## Label merge order

nix-oci merges auto-generated labels with user labels at image build time.
**User labels always win**:

```
generatedLabels // nixosEvalHardeningLabels // userLabels
```

This means you can override any auto-generated label by setting it
explicitly in `labels`:

```nix
oci.containers.my-app = {
  package = pkgs.myApp;
  labels = {
    # Override auto-generated title
    "org.opencontainers.image.title" = "My Custom Title";
    # Add labels that can't be auto-derived
    "org.opencontainers.image.source" = "https://github.com/my-org/my-app";
    "org.opencontainers.image.vendor" = "My Organization";
  };
};
```

## Why it matters

- **Compliance**: [Kyverno has a built-in "Require Image Source" policy](https://kyverno.io/policies/other/require-image-source/require-image-source/)
  that rejects images missing `org.opencontainers.image.source`.
  Auto-labeling makes nix-oci images pass these checks for all
  derivable annotations.
- **Single source of truth**: nix-oci derives labels from the same Nix
  expressions that define the package and container; no drift between
  the image and its metadata.
- **Fleet visibility**: tools like `skopeo inspect`, Trivy, and
  container registries display OCI annotations. Auto-labeling makes
  every image self-describing.
- **Reproducible metadata**: all auto-generated labels are deterministic
  and they don't break bit-for-bit reproducibility.
- **Ecosystem alignment**: [Chainguard](https://edu.chainguard.dev/chainguard/chainguard-images/overview/)
  sets the same OCI standard annotations on their distroless images.
  nix-oci follows the same convention.

## Further reading

- [Container metadata wiring](./container-metadata-wiring.md): how labels flow into OCI config
- [Security defaults](./security-defaults.md): non-root, distroless, hardening
- [OCI Image Spec: Annotations](https://specs.opencontainers.org/image-spec/annotations/)
- [Kyverno: Require Image Source](https://kyverno.io/policies/other/require-image-source/require-image-source/)
- [Kyverno: ImageValidatingPolicy](https://kyverno.io/docs/policy-types/image-validating-policy/)
- [K8s Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Snyk: How and when to use Docker labels](https://snyk.io/blog/how-and-when-to-use-docker-labels-oci-container-annotations/)
