# Flake-parts module extracted from ./flake.nix so both the standalone
# how-to flake AND the repo's `tests/` BDD suite can consume the same
# container definition. Keeping them in sync is the whole point — it
# guarantees the commands shown in `docs/content/getting-started.md`
# resolve against a real flake output.
{ ... }:
{
  config.perSystem =
    { pkgs, ... }:
    {
      config.oci.containers.hello = {
        package = pkgs.hello;
      };
    };
}
