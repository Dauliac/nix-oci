+++
title = "nix-lib functions"
+++

# nix-lib Functions

Library functions available as `config.lib.oci.*` (per-system) after importing the nix-oci flake-parts module.

## Overriding functions

All nix-oci library functions can be overridden by consumers. Since they are declared as `nix-lib.lib.oci.*` module options, you can replace any function in your own flake-parts module:

```nix
# In your flake module:
perSystem = { lib, ... }: {
  nix-lib.lib.oci.mkAutoLabels = {
    type = lib.types.functionTo lib.types.attrs;
    description = "My custom label generator";
    fn = { ... }: {
      # your custom labels
    };
  };
};
```

The overridden function will be used everywhere nix-oci calls `config.lib.oci.mkAutoLabels`, including image builders and deploy modules. This lets you customize or extend any behavior without forking nix-oci.

See also:

- [Source: `nix/modules/oci/lib/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci/lib) -- image builders, layers, labels, security, ports, architecture
- [Source: `nix/modules/oci/security/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci/security) -- CVE, SBOM, signing, compliance, credentials leak, linting
- [Source: `nix/modules/oci/testing/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci/testing) -- CST, dgoss, dive, podman sandbox

---

<!-- OPTIONS:nix-lib -->
