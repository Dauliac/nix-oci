{ lib, ... }:
{
  options.lint.dockle.ignore = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "List of Dockle checkpoint IDs to ignore (e.g. `CIS-DI-0001`).";
    default = [
      "CIS-DI-0005"
      "CIS-DI-0006"
    ];
    example = [
      "CIS-DI-0001"
      "DKL-DI-0006"
    ];
  };
}
