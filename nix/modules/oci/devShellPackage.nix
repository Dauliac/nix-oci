# OCI devShellPackage option
{ lib, ... }:
{
  options.oci.devShellPackage = lib.mkOption {
    type = lib.types.package;
    description = "The package to use for the development shell.";
  };
}
