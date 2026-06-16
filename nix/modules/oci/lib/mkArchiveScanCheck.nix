# Factory: generate hermetic (nix build sandbox) checks for archive-based security tools.
#
# Companion to mkArchiveScanScript — same pattern but as a runCommandLocal derivation
# for `nix flake check` integration.
{ ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
    in
    {
      nix-lib.lib.oci.mkArchiveScanCheck = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Factory: create a runCommandLocal derivation that extracts a transient
          docker archive and runs a security tool against it inside the Nix sandbox.
        '';
        file = "nix/modules/oci/lib/mkArchiveScanCheck.nix";
        fn =
          {
            # Derivation name (e.g. "lint-dockle-mycontainer")
            name,
            # Description for meta
            metaDescription,
            # The OCI image derivation
            oci,
            # skopeo package
            skopeo,
            # Tool packages to include in nativeBuildInputs
            toolPackages,
            # Shell command to run (has access to archive.tar in $PWD)
            checkCommand,
            # Extra nativeBuildInputs beyond tool + skopeo + gnutar + python3
            extraBuildInputs ? [ ],
          }:
          pkgs.runCommandLocal name
            {
              nativeBuildInputs = toolPackages ++ [
                skopeo
                pkgs.gnutar
                pkgs.python3
              ] ++ extraBuildInputs;
              meta.description = metaDescription;
            }
            ''
              ${ociLib.mkTransientArchive {
                inherit oci skopeo;
              }}
              export DOCKER_CONFIG="$(mktemp -d)"
              ${checkCommand}
              touch $out
            '';
      };
    };
}
