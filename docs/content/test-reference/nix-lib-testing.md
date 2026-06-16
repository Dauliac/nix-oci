+++
title = "nix-lib: testing functions"
+++

# Testing Library Functions

These functions are available as `config.lib.oci.*` (per-system) after importing
the `nix-oci-test` flake module. They are **only loaded when the test module is
imported** — consumers who only import `nix-oci` will not see these functions.

Includes:
- **Container probes** — `mkContainerProbe`, `mkHermeticContainerProbe`
- **Testing tools** — `mkCheckDive`, `mkScriptDgoss`, `mkCheckDgoss`
- **Container structure tests** — `mkScriptContainerStructureTest`, `mkCoherenceCst`
- **Security probes** — `mkScriptAmicontained`, `mkScriptCdk`, `mkScriptDeepce`, `mkScriptLinpeas`
- **Sandbox** — `mkPodmanSandboxCheck`

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

Source: [`nix/modules/oci/_testing/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci/_testing)

---

<!-- OPTIONS:nix-lib-testing -->
