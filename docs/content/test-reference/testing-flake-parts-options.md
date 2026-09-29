+++
title = "Testing flake-parts options"
+++

# Testing Flake-Parts Options

These options are available when you import the `nix-oci-test` flake module
alongside the main `nix-oci` module. Importing the test module autoenables
it; set `testing.enable = false` to opt out.

The NixOS test module (`nix-oci-test`) exposes autodiscovered `testing.*`
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
options (for example, `services.dockerRegistry.port = 5001`).

The test module provides:
- **BDD test collector**, discovers `.test.nix` files and collects test specs
- **VM test builder**, generates NixOS VM tests from BDD specs
- **Container probes**, amicontained, CDK, DEEPCE, linPEAS
- **Testing tools**, dive, dgoss, CST, podman sandbox
- **Policy runners**, infrastructure for build-time policy gates
- **Test apps**, `nix run .#app-<tool>-<container>`

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

## BDD assertion vocabulary

Test specs contributed under `test.oci.perContainer.<option>` use the typed
assertion vocabulary declared in [`_option-test-spec.nix`](https://github.com/Dauliac/nix-oci/blob/main/nix/modules/oci/testing/_option-test-spec.nix).
The generic vocabulary covers image inspection, oneshot commands, HTTP checks,
and process/systemd probes.

The behavioral coverage tier adds eight typed helpers under `assertions.*`:

| Helper | Purpose |
|---|---|
| [`syscallBlocked`](./nix-lib-testing.html#syscallblocked) | A syscall from inside the container fails with a specific errno. |
| [`fsWriteBlocked`](./nix-lib-testing.html#fswriteblocked) | A path write fails with a specific errno (default `EROFS`). |
| [`dnsResolutionFails`](./nix-lib-testing.html#dnsresolutionfails) | `getaddrinfo` fails for a given hostname. |
| [`tlsHandshakeFails`](./nix-lib-testing.html#tlshandshakefails) | HTTPS to a URL fails with a cert-verification error. |
| [`envVarSet`](./nix-lib-testing.html#envvarset) | An env var in `/proc/1/environ` matches an exact value or regex. |
| [`sociZtocPresent`](./nix-lib-testing.html#soci-ztoc-present) | A SOCI v2 zTOC referrer manifest exists for a pushed image. |
| [`manifestDigestMatches`](./nix-lib-testing.html#manifestdigestmatches) | Two builds of a container produce identical manifest digests. |
| [`firewallPortOpen`](./nix-lib-testing.html#firewallportopen) | The NixOS firewall accepts a declared port on TCP or UDP. |

See the [nix-lib testing reference](./nix-lib-testing.html#bdd-assertion-helpers)
for inputs and a minimal example of each helper.

<!-- OPTIONS:testing-flake-parts -->
