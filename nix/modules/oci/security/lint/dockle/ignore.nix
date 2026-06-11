{ lib, ... }:
{
  options.oci.lint.dockle.ignore = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "List of Dockle checkpoint IDs to ignore (e.g. `CIS-DI-0001`).";
    default = [
      # Docker Content Trust is irrelevant for nix2container
      # images since they are built locally from the Nix store.
      "CIS-DI-0005"
      # HEALTHCHECK instruction check is irrelevant since
      # there is no Dockerfile. Healthchecks are set via
      # the image config by nix-oci service adapters.
      "CIS-DI-0006"
    ];
    example = [
      "CIS-DI-0001"
      "DKL-DI-0006"
    ];
  };
}
