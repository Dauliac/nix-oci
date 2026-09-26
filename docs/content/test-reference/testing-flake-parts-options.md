+++
title = "Testing flake-parts options"
+++

# Testing Flake-Parts Options

These options are available when you import the `nix-oci-test` flake module
alongside the main `nix-oci` module. Importing the test module auto-enables
it; set `testing.enable = false` to opt out.

The NixOS test module (`nix-oci-test`) exposes auto-discovered `testing.*`
options under [`nix/modules/deploy/nix-oci/nixos/_test/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/deploy/nix-oci/nixos/_test):

- `testing.enable` (`mkEnableOption`)
- `testing.registry.enable`, `testing.registry.port`
- `testing.extraPackages`
- `testing.cosign.localKeys`
- `testing.db.trivy.path`, `testing.db.grype.path`
- `testing.turbo.forceEnable`
- `testing.appScripts`

The module also configures Podman, a local Docker registry, cosign key
generation, and overlay storage. Override any of these via standard NixOS
options (e.g., `services.dockerRegistry.port = 5001`).

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

Source: [`nix/modules/oci/testing/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci/testing)

<!-- OPTIONS:testing-flake-parts -->
