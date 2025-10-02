{ ... }:
{
  imports = [
    ./apps.nix
    ./checks.nix
    # (import ./dev-shell.nix localflake)
    ./packages.nix
  ];
}
