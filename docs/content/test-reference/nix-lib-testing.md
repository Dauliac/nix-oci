+++
title = "nix-lib: testing functions"
+++

# Testing Library Functions

These functions are available as `config.lib.oci.*` (per-system) after importing
the `nix-oci-test` flake module. They're **only loaded when the test module is
imported**, consumers who only import `nix-oci` won't see these functions.

Includes:
- **Container probes**, [`mkContainerProbe`](#mkcontainerprobe), [`mkHermeticContainerProbe`](#mkhermeticcontainerprobe)
- **Testing tools**, [`mkCheckDive`](#mkcheckdive), [`mkScriptDgoss`](#mkscriptdgoss), [`mkCheckDgoss`](#mkcheckdgoss)
- **Container structure tests**, [`mkScriptContainerStructureTest`](#mkscriptcontainerstructuretest), [`mkCoherenceCst`](#mkcoherencecst)
- **Security probes**, [`mkScriptAmicontained`](#mkscriptamicontained), [`mkScriptCdk`](#mkscriptcdk), [`mkScriptDeepce`](#mkscriptdeepce), [`mkScriptLinpeas`](#mkscriptlinpeas)
- **VM sandbox**, [`mkVMCheck`](#mkvmcheck)

```nix
{
  imports = [
    inputs.nix-oci.modules.flake.nix-oci
    inputs.nix-oci.modules.flake.nix-oci-test  # required for test lib functions
  ];

  perSystem = { config, ... }: {
    # Now config.lib.oci.mkContainerProbe is available
    checks.my-probe = config.lib.oci.mkCheckDive {
      perSystemConfig = config;
      containerId = "my-container";
    };
  };
}
```

Source: [`nix/modules/oci/testing/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci/testing)

---

## BDD assertion helpers

BDD test specs declared in `.test.nix` files use a typed assertion vocabulary
defined in [`nix/modules/oci/testing/_option-test-spec.nix`](https://github.com/Dauliac/nix-oci/blob/main/nix/modules/oci/testing/_option-test-spec.nix).
The generic helpers (`imageConfig`, `labels`, `fileContains`, `fileNotContains`,
`succeeds`, `fails`, `httpResponds`, `processEnv`, `containerInspect`,
`systemdProps`, `runtime`) cover most cases. The behavioral coverage tier adds
eight typed helpers that target specific runtime, build, and network
observations the generic vocabulary can't express cleanly.

Each helper below lists purpose, expected inputs, and a minimal example. All
helpers are attributes of `assertions` inside a BDD scenario.

### syscallBlocked

**Purpose.** Assert that a specific syscall invoked from inside the running
container fails with the expected errno. Used to verify seccomp filter effects
without depending on tool-specific error strings.

**Inputs.**
- `syscall` (string), the syscall name (for example `mount`, `unshare`, `bpf`).
- `probe` (string), the binary to invoke that triggers the syscall.
- `args` (string, optional), arguments passed to the probe.
- `errno` (string, optional, default `"EPERM"`), the expected errno tag.

**Example.**

```nix
assertions.syscallBlocked = {
  syscall = "mount";
  probe = "/bin/mount";
  args = "-t tmpfs none /tmp";
  errno = "EPERM";
};
```

### fsWriteBlocked

**Purpose.** Assert that writing to a filesystem path fails with the expected
errno. Used to verify `readOnlyRootfs` and volume-mount policies.

**Inputs.**
- `path` (string), absolute path inside the container.
- `errno` (string, optional, default `"EROFS"`), the expected errno tag.

**Example.**

```nix
assertions.fsWriteBlocked = {
  path = "/new-file";
  errno = "EROFS";
};
```

### dnsResolutionFails

**Purpose.** Assert that name resolution for a hostname fails from inside the
container. Used to verify `hardening.disableDns`.

**Inputs.**
- `hostname` (string), the hostname to resolve.

**Example.**

```nix
assertions.dnsResolutionFails = {
  hostname = "example.com";
};
```

### tlsHandshakeFails

**Purpose.** Assert that a TLS handshake to a public HTTPS endpoint fails with
a certificate-verification error from inside the container. Used to verify
`hardening.noTlsTrustStore`.

**Inputs.**
- `url` (string), the HTTPS URL to probe (must include scheme).

**Example.**

```nix
assertions.tlsHandshakeFails = {
  url = "https://example.com";
};
```

### envVarSet

**Purpose.** Assert that an environment variable is present in `/proc/1/environ`
with an exact value or a regex match. Complements `processEnv` when the value
is a store path or otherwise not known statically.

**Inputs.**
- `name` (string), the env var name.
- `value` (string, optional), exact expected value.
- `matches` (string, optional), regular expression the value must match.

Exactly one of `value` or `matches` must be set.

**Example.**

```nix
assertions.envVarSet = {
  name = "LD_PRELOAD";
  matches = ".*/lib/libjemalloc\\.so.*";
};
```

### sociZtocPresent

**Purpose.** Assert that a container pushed to the in-VM registry has a SOCI
v2 zTOC referrer manifest and, optionally, that the zTOC was generated with
the expected span size.

**Inputs.**
- `image` (string), the pushed image reference (for example
  `localhost:5000/myapp:latest`).
- `spanSize` (string, optional), the expected span size (for example `"1MiB"`).

**Example.**

```nix
assertions.sociZtocPresent = {
  image = "localhost:5000/myapp:latest";
  spanSize = "1MiB";
};
```

### manifestDigestMatches

**Purpose.** Build a container twice from the same input and assert that the
OCI manifest digest is identical across builds. Used by the reproducibility
test to detect non-determinism.

**Inputs.**
- `container` (raw), the container config to build twice.

**Example.**

```nix
assertions.manifestDigestMatches = {
  container = {
    package = pkgs.hello;
  };
};
```

### firewallPortOpen

**Purpose.** Assert that the NixOS firewall has an accept rule for a declared
port on a specific protocol, verified against `nft list ruleset`. Used to
cover the ports triple-write path (OCI ExposedPorts + runner `--publish` +
firewall).

**Inputs.**
- `port` (int), the port number.
- `protocol` (string, optional, default `"tcp"`), either `"tcp"` or `"udp"`.

**Example.**

```nix
assertions.firewallPortOpen = {
  port = 8080;
  protocol = "tcp";
};
```

<!-- OPTIONS:nix-lib-testing -->
