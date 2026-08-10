# This is the public-facing flake module that bundles all nix-oci dependencies
# Users import this module and don't need to declare nix2container or other deps
inputs:
{
  lib,
  config,
  ...
}:
{
  imports = [
    # Import nix-lib for library management (typing, testing, docs)
    inputs.nix-lib.flakeModules.default
    # Enable typed flake.modules.{nixos,homeManager,...} output
    inputs.flake-parts.flakeModules.modules
    # Auto-discover all modules using import-tree
    (inputs.import-tree ./modules)
  ];

  # Opt-in surface for the `flake.tests` output that nix-lib auto-emits
  # from `nix-lib.lib.*` metadata. Hidden by default so extenders and the
  # BDD `./tests` flake don't inherit the library's private unit-test
  # surface. Root's dev partition sets this to `true` for local dev.
  options.oci.flake.exposeUnitTests = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether to expose the `flake.tests` output (auto-generated from
      `nix-lib.lib.*` metadata). Leave `false` on any flake that only
      consumes nix-oci; enable only in the library's own dev root.
    '';
  };

  config.flake.tests = lib.mkIf (!config.oci.flake.exposeUnitTests) (lib.mkForce { });

  # Override the package defaults to use our bundled dependencies
  config.perSystem =
    { system, ... }:
    {
      _module.args.nixLibNixosModule = inputs.nix-lib.nixosModules.default;
      oci.packages = {
        nix2container = inputs.nix2container.packages.${system}.nix2container;
        skopeo = inputs.nix2container.packages.${system}.skopeo-nix2container;
      }
      // (
        if inputs ? nix2container-turbo then
          {
            skopeoTurbo = inputs.nix2container-turbo.packages.${system}.skopeo;
          }
        else
          { }
      );
    };
}
