# Factory: generate archive-based security scanning scripts.
#
# Most security tools (trivy, grype, dockle, syft, conftest) follow the same pattern:
#   1. Create transient archive from OCI image
#   2. Run tool against archive.tar
#   3. Optionally write report under CIMERA_REPORT_DIR
#
# This factory captures the boilerplate; each tool only provides its unique parts.
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
      nix-lib.lib.oci.mkArchiveScanScript = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Factory: create a writeShellScriptBin that extracts a transient docker
          archive from an OCI image and runs a security scanning tool against it.
        '';
        file = "nix/modules/oci/lib/mkArchiveScanScript.nix";
        fn =
          {
            # Script name (e.g. "trivy-mycontainer")
            name,
            # The OCI image derivation (perSystemConfig.internal.OCIs.${containerId})
            oci,
            # skopeo package
            skopeo,
            # Shell commands to run after archive extraction (the actual scan).
            # Has access to: archive.tar in $WORK, any vars from extraSetup.
            scanCommand,
            # Extra shell setup before scanCommand (e.g. ignore file generation)
            extraSetup ? "",
            # Shell block for CIMERA_REPORT_DIR output (use ociLib.mkReportBlock or raw shell)
            reportBlock ? "",
            # Whether to set up DOCKER_CONFIG (most tools need this, vulnix doesn't)
            needsDockerConfig ? true,
            # Whether to create the transient archive (vulnix operates on store path directly)
            needsArchive ? true,
          }:
          let
            mkTransientArchive = ociLib.mkTransientArchive {
              inherit oci skopeo;
            };
          in
          pkgs.writeShellScriptBin name ''
            ${ociLib.shellPreamble}
            ${lib.optionalString needsDockerConfig ''export DOCKER_CONFIG="$(mktemp -d)"''}
            WORK="$(mktemp -d)"
            trap 'rm -rf "$WORK"' EXIT
            cd "$WORK"
            ${lib.optionalString needsArchive mkTransientArchive}
            ${extraSetup}
            ${scanCommand}
            ${reportBlock}
          '';
      };
    };
}
