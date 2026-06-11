+++
title = "Policy checking & integrity testing"
description = "OCI config policy checking with Conftest/OPA Rego, container-structure-test with coherence auto-generation, dgoss, Dive, and container security probes"
+++

# Policy checking & integrity testing

## OCI config policy checking (Conftest)

[Conftest](https://www.conftest.dev/) validates structured data against
**Open Policy Agent (OPA)** rules written in Rego. nix-oci uses it to
check the OCI image config JSON at build time, catching configuration
mistakes that scanners like Trivy and Dockle do not cover.

### What it checks

nix-oci ships built-in Rego policies that verify:

| Rule | Severity | Rationale |
|---|---|---|
| Container runs as root | **deny** | Root inside the container can escalate to host root via kernel exploits |
| User field is empty | **deny** | An empty User defaults to root at runtime |
| Secrets in env vars | **deny** | Env vars with `PASSWORD`, `SECRET`, `TOKEN`, `API_KEY` in the name |
| Missing `org.opencontainers.image.source` label | **warn** | Traceability back to source repository |
| Missing `org.opencontainers.image.description` label | **warn** | Image provenance metadata |
| Missing or empty Entrypoint | **deny** | Every container should have an explicit entrypoint |

### How it works

The Conftest script:

1. Converts the nix2container image to a Docker archive (via skopeo).
2. Extracts the OCI image config JSON from the archive manifest.
3. Runs `conftest test` against the config with the configured Rego
   policy directory.
4. Optionally writes a JSON report for CI integration.

No container runtime is needed. The check is purely build-time.

### Enable it

See [`oci.policy.conftest`](../../reference/flake-parts-options.html) in the option reference.

```nix
# Global (all containers)
oci.policy.conftest.enabled = true;
```

### Per-container configuration

```nix
oci.containers.my-app.policy.conftest = {
  enabled = true;
  # Use custom policies instead of the built-in ones:
  # policyDir = ./my-policies;
  # Check additional Rego namespaces:
  # namespaces = [ "main" "custom" ];
};
```

### Extending built-in policies (extraPolicyDirs)

The recommended way to add organisation-specific rules is
`extraPolicyDirs`. It merges your custom Rego directories *with* the
built-in policies — both run together:

```nix
oci.policy.conftest = {
  enabled = true;
  extraPolicyDirs = [ ./my-org-policies ];
};
```

Create `.rego` files in your directory. Each file declares a `package`
(namespace) and defines `deny` or `warn` rules. The input is the OCI
image config JSON:

```rego
package main

warn[msg] {
  not input.config.Labels["team"]
  msg := "missing 'team' label"
}
```

If a file in `extraPolicyDirs` has the same name as a built-in (e.g.,
`oci.rego`), the extra version takes precedence — allowing selective
override of specific built-in rules.

### Replacing built-in policies (policyDir)

To use *only* your own rules and disable the built-ins entirely,
set `policyDir`:

```nix
oci.policy.conftest.policyDir = ./my-policies;
```

### Running the check

```bash
nix run .#oci-policy-conftest-my-app
```

### Why Conftest alongside Dockle and Trivy?

Dockle checks CIS benchmarks against image layers. Trivy compliance
checks a fixed set of CIS rules. Conftest lets you write **arbitrary
custom policies** in Rego: team labels, naming conventions, entrypoint
patterns, environment variable allow-lists, or anything else your
organization requires. It is the extensibility layer.

### Three-layer validation model

Conftest policy composition is part of a broader validation
architecture. See [Policy composition and coherence testing](../policy-coherence-testing.html)
for the full design: auto-generated coherence checks, built-in best
practices, and user-extensible policy composition.

## Container integrity testing

Beyond security scanning, nix-oci integrates structural and
behavioral testing tools:

| Tool | Purpose | Option |
|---|---|---|
| **container-structure-test** | Validate filesystem, commands, metadata | [`oci.test.containerStructureTest.enabled`](../../reference/flake-parts-options.html) |
| **dgoss** | Behavioral testing with goss inside the container | [`oci.test.dgoss.enabled`](../../reference/flake-parts-options.html) |
| **Dive** | Image layer efficiency analysis | [`oci.test.dive.enabled`](../../reference/flake-parts-options.html) |
| **amicontained** | Container introspection: runtime, capabilities, seccomp, namespaces | [`oci.test.amicontained.enabled`](../../reference/flake-parts-options.html) |
| **DEEPCE** | Container escape detection: socket exposure, privileged mode, dangerous mounts | [`oci.test.deepce.enabled`](../../reference/flake-parts-options.html) |
| **linPEAS** | Privilege escalation audit: SUID, capabilities, writable paths, kernel exploits | [`oci.test.linpeas.enabled`](../../reference/flake-parts-options.html) |

### CST coherence checking (auto-generated)

When `test.containerStructureTest.coherence = true` (the default),
nix-oci auto-generates a `metadataTest` config from the container's
module options. This validates that the built OCI artifact's user,
entrypoint, ports, labels, environment, working directory, and volumes
match the declared Nix config — no hand-written YAML needed.

The auto-generated config runs alongside any user-supplied CST YAML
files. To add filesystem or command tests on top of coherence, supply
both:

```nix
oci.containers.my-app.test.containerStructureTest = {
  enabled = true;
  # coherence = true is the default
  configs = [ ./my-extra-tests.yaml ];
};
```

To disable coherence and use only hand-written configs:

```nix
oci.containers.my-app.test.containerStructureTest = {
  enabled = true;
  coherence = false;
  configs = [ ./test.yaml ];
};
```

See [Policy composition and coherence testing](../policy-coherence-testing.html)
for the full design rationale.

### Container probes (amicontained, DEEPCE, linPEAS)

[amicontained](https://github.com/genuinetools/amicontained),
[DEEPCE](https://github.com/stealthcopter/deepce), and
[linPEAS](https://github.com/peass-ng/PEASS-ng) must run **inside**
the container. nix-oci solves this without polluting the production
image via the shared `mkContainerProbe` infrastructure, which
bind-mounts tools from the Nix store at test time:

- **Static binaries** (amicontained) are mounted directly as the
  entrypoint.
- **Shell scripts** (DEEPCE, linPEAS) are co-mounted with a static
  busybox that provides `/bin/sh`, since hardened images may lack a
  shell.

The production image is tested as-is. If hardening options (seccomp,
dropped capabilities, read-only rootfs) are effective, these probes
confirm it.

See the [options reference](../../reference/flake-parts-options.html)
for per-tool configuration (`oci.test.amicontained`,
`oci.test.deepce`, `oci.test.linpeas`).

### dgoss hermetic mode

dgoss can run as a **pure Nix derivation** using Podman inside the
Nix sandbox. This makes container tests fully reproducible and
cacheable:

```nix
oci.test.dgoss = {
  enabled = true;
  hermetic = true;  # requires extra-sandbox-paths = /sys/fs/cgroup
};
```
