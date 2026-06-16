+++
title = "Testing flake-parts options"
+++

# Testing Flake-Parts Options

These options are available when you import the `nix-oci-test` flake module
alongside the main `nix-oci` module. Importing the test module is all that's
needed — there is no `testing.enable` flag.

The NixOS test module (`nix-oci-test`) is pure config with no user-facing options.
It configures Podman, a local Docker registry, cosign key generation, and overlay
storage. Override any of these via standard NixOS options (e.g.,
`services.dockerRegistry.port = 5001`).

The test module provides:
- **BDD test collector** — discovers `.test.nix` files and collects test specs
- **VM test builder** — generates NixOS VM tests from BDD specs
- **Container probes** — amicontained, CDK, DEEPCE, linPEAS
- **Testing tools** — dive, dgoss, CST, podman sandbox
- **Policy runners** — infrastructure for build-time policy gates
- **Test apps** — `nix run .#app-<tool>-<container>`

```nix
{
  imports = [
    inputs.nix-oci.modules.flake.nix-oci
    inputs.nix-oci.modules.flake.nix-oci-test
  ];

  perSystem = { pkgs, ... }: {
    # BDD test specs are contributed by .test.nix files
    # and collected into test.oci.perContainer.*
    test.oci.perContainer.my-option = {
      eval-defaults = {
        given = "a container with default settings";
        "when" = "the container config is evaluated";
        "then" = "evaluation succeeds";
        level = "build";
        target = "oci";
        container.package = pkgs.hello;
      };
    };
  };
}
```

Source: [`nix/modules/oci/_testing/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci/_testing)

<!-- OPTIONS:testing-flake-parts -->
