# NixOS: test infrastructure module.
#
# Registers flake.modules.nixos.nix-oci-test which provides:
# - Podman with Docker-compat socket
# - Localhost Docker registry
# - Pinned vulnerability DB injection
# - Local cosign key generation
# - Overlay storage
{ ... }:
{
  flake.modules.nixos.nix-oci-test =
    { ... }:
    {
      imports =
        # Auto-discovered option files (enable, registry, turbo, cosign, db, extra-packages)
        (import ./_test/default.nix) ++ [
          # Explicit config files (_-prefixed)
          ./_test/_registry-config.nix
          ./_test/_podman-config.nix
          ./_test/_db-config.nix
          ./_test/_cosign-config.nix
          ./_test/_apps-config.nix
        ];
    };
}
