# nix-oci

**nix-oci** is a [flake-parts](https://github.com/hercules-ci/flake-parts) module designed to streamline the management of OCI (Open Container Initiative) repositories using the Nix package manager. By leveraging [nix2container](https://github.com/nlewo/nix2container) as its backend, nix-oci facilitates the declarative creation and handling of container images, ensuring reproducibility and efficiency in containerized environments.

## Features

- **Seamless Integration with Container Ecosystem**: nix-oci offers compatibility with tools like Docker and Podman, simplifying integration into existing workflows.
- **Centralized Build Definitions**: It consolidates build configurations within Nix flakes, reducing redundancy across projects.
- **Debug-Friendly Images**: The module enables the creation of debug variants of images by incorporating additional tools (e.g., `curl`, `bash`) and setting an infinite sleep as the entrypoint for troubleshooting purposes.
- **Efficient Monorepo Management**: nix-oci supports building multiple containers within monorepos, sharing common packages in the Nix store to optimize storage and build times.
- **Minimalistic and Secure Containers**: It promotes the creation of minimalistic containers by allowing users to specify only the necessary packages, facilitating single-binary containers that run as non-root users by default.
- **Accelerated Builds**: Utilizing the Nix store, nix-oci accelerates build processes by avoiding redundant storage of OCI archives and leveraging existing packages available in the development shell or package outputs.

## Why Use nix-oci?

### Define a Minimalistic Container in Just a Few Lines!

Creating an OCI-compliant container with nix-oci is incredibly simple. If you need a minimalistic, secure container running a single binary, just specify the package and let nix-oci handle the rest:

```nix
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalist = {
            package = pkgs.kubectl;
          };
        };
      };
  };
}
```

That’s it! The image is automatically built with a minimal footprint, runs as a **non-root** user by default, and ensures maximum security and efficiency. Stop writing extensive Dockerfiles—embrace the declarative power of Nix with nix-oci! 🚀

## Getting Started

To quickly start a new project using the nix-oci template, you can initialize a new flake with the following command:

```bash
nix flake init -t github:Dauliac/nix-oci
```

This command sets up a new Nix flake project pre-configured with nix-oci, allowing you to define and build OCI containers efficiently.

For comprehensive examples and test cases, refer to the [examples](./examples) directory in the repository.

## Inspirations

nix-oci draws inspiration from projects such as [skaffold](https://skaffold.dev/) and [treefmt](https://github.com/numtide/treefmt), aiming to simplify recurring challenges in container production for developers and Site Reliability Engineers (SREs).

## Contributing

Contributions are welcome! Please refer to the [CONTRIBUTING.md](./CONTRIBUTING.md) file for guidelines on how to get involved.

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

## Acknowledgments

Special thanks to the contributors of [nix2container](https://github.com/nlewo/nix2container) and [flake-parts](https://github.com/hercules-ci/flake-parts) for their foundational work that made this project possible.
