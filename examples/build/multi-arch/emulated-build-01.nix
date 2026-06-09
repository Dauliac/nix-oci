# Emulated multi-arch: build all arches via QEMU binfmt emulation.
#
# Instead of cross-compiling with pkgsCross, this imports nixpkgs for the
# target system and builds natively under QEMU user-mode emulation.
# Slower than cross-compilation, but works for any package.
#
# Prerequisites:
#   - NixOS: boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
#   - nix.conf: extra-platforms = aarch64-linux
#
# Produces:
#   - `oci-multiarch-<name>` package (OCI directory layout)
#   - `oci-push-multiarch-<name>` app (push to registry)
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          emulatedBuild = {
            package = pkgs.hello;
            registry = "localhost:5000";
            tags = [
              "1.0.0"
              "latest"
            ];
            multiArch = {
              systems = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              emulatedBuild.enable = true;
            };
            # No archConfigs needed — auto-inferred from target-system nixpkgs
          };
        };
      };
  };
}
