# nix-oci

A [flake-parts](https://flake.parts), [NixOS](https://nixos.org/manual/nixos/stable/) and [Home Manager](https://nix-community.github.io/home-manager/) module system for OCI containers, powered by [nix2container](https://github.com/nlewo/nix2container).

nix-oci lets you **build**, **deploy** and **run** containers entirely from Nix — including building images directly from NixOS service definitions.

## Features

- **Build OCI images** declaratively from packages or NixOS modules
- **Deploy and run** containers on NixOS and Home Manager via a unified `oci.*` API
- **Build containers from NixOS services** — write `services.nginx.enable = true` and get a minimal container image
- **Multi-arch cross-compilation** — build `aarch64` images on `x86_64` without emulation
- **Security** — CVE scanning (Trivy, Grype, Vulnix), SBOM generation (Syft), credentials leak detection, image signing (cosign)
- **Testing** — Container Structure Tests, dgoss, dive
- **Debug variants** — add shells and tools to any image for troubleshooting

## Quick Start: Build an image (flake-parts)

```nix
{
  inputs.nix-oci.url = "github:Dauliac/nix-oci";

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nix-oci.modules.flake.nix-oci ];

      oci.enabled = true;

      perSystem = { pkgs, ... }: {
        oci.containers.hello = {
          package = pkgs.hello;
        };
      };
    };
}
```

Or use the template:

```bash
nix flake init -t github:Dauliac/nix-oci
```

## Quick Start: Deploy a container (NixOS)

```nix
{ inputs, pkgs, ... }:
{
  imports = [ inputs.nix-oci.modules.nixos.nix-oci ];

  oci = {
    enable = true;
    backend = "podman";
    containers.my-server = {
      package = pkgs.python3Minimal;
      entrypoint = [ "${pkgs.python3Minimal}/bin/python3" "-m" "http.server" "8080" ];
      autoStart = true;
      ports = [ "8080:8080" ];
    };
  };
}
```

## Quick Start: Build from a NixOS service

```nix
perSystem = { ... }: {
  oci.containers.my-caddy = {
    nixosConfig = {
      enable = true;
      mainService = "caddy";
      modules = [
        ({ ... }: {
          services.caddy = {
            enable = true;
            virtualHosts."localhost:8080".extraConfig = ''
              respond "Hello from nix-oci!"
            '';
          };
        })
      ];
    };
    isRoot = true;
  };
};
```

## Documentation

- [Full documentation](https://dauliac.github.io/nix-oci/) (built with [NDG](https://github.com/feel-co/ndg))
- [nix-oci on flake.parts](https://flake.parts/options/nix-oci.html)
- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [nix2container](https://github.com/nlewo/nix2container)
- [flake-parts](https://flake.parts)

## Examples

See the [examples](./examples) directory:

- [`examples/build/`](./examples/build/) — flake-parts image building
- [`examples/deploy-nixos/`](./examples/deploy-nixos/) — NixOS deployment
- [`examples/deploy-home-manager/`](./examples/deploy-home-manager/) — Home Manager deployment

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License

MIT — see [LICENSE](./LICENSE).

## Acknowledgments

Thanks to the contributors of [nix2container](https://github.com/nlewo/nix2container) and [flake-parts](https://github.com/hercules-ci/flake-parts).
