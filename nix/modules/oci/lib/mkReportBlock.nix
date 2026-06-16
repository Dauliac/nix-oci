# Generate a CIMERA_REPORT_DIR shell block for security/testing scripts.
{ ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.mkReportBlock = {
        type = lib.types.functionTo lib.types.str;
        description = "Shell snippet that writes a report file under CIMERA_REPORT_DIR (no-op when unset).";
        file = "nix/modules/oci/lib/mkReportBlock.nix";
        fn =
          {
            # Shell command that produces the report (can reference $WORK, etc.)
            reportCommand,
            # Filename under CIMERA_REPORT_DIR
            reportName,
          }:
          ''
            if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
              mkdir -p "$CIMERA_REPORT_DIR"
              ${reportCommand}
            fi
          '';
      };
    };
}
