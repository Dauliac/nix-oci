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

<!-- OPTIONS:nix-lib-testing -->
