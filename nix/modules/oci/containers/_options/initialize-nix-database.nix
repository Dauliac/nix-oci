# Shared: populate the Nix database inside the container.
#
# When enabled, nix2container registers all copyToRoot closure paths in
# /nix/var/nix/db/db.sqlite so that nix commands (nix build, nix eval, …)
# work inside the container.
#
# Disabled by default because copyToRoot paths are flattened to / and the
# buildEnv store path itself becomes a phantom DB entry. This is harmless
# for in-container nix usage but can confuse CI pipelines that check DB
# consistency. Enable this when you need to run nix inside the container.
{ lib, ... }:
{
  options.initializeNixDatabase = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Populate the Nix database (`/nix/var/nix/db/db.sqlite`) with the
      closure of all store paths shipped in the image.

      Enable this when you need to run Nix commands (`nix build`,
      `nix eval`, `nix-store -q`, …) inside the container. Without it,
      the Nix store directory contains packages but the database is empty,
      causing Nix to believe no packages are installed.

      Disabled by default because `copyToRoot` flattens store paths to `/`,
      creating phantom database entries for the flattened derivations.
      This is harmless for in-container Nix usage but may confuse workflows
      that validate database-vs-disk consistency.
    '';
    example = true;
  };
}
