# Generate a NIX_OCI_REPORT_DIR shell block for security/testing scripts.
{ ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.mkReportBlock = {
        type = lib.types.functionTo lib.types.str;
        description = "Shell snippet that writes a report file under NIX_OCI_REPORT_DIR (no-op when unset).";
        file = "nix/modules/oci/lib/mkReportBlock.nix";
        fn =
          {
            # Shell command that produces the report (can reference $WORK, etc.)
            reportCommand,
            # Filename under NIX_OCI_REPORT_DIR
            reportName,
          }:
          ''
            if [ -n "''${NIX_OCI_REPORT_DIR:-}" ]; then
              mkdir -p "$NIX_OCI_REPORT_DIR"
              ${reportCommand}
            fi
          '';
      };
    };
}
