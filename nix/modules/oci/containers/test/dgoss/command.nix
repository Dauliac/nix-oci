# Container test.dgoss.command option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.test.dgoss.command = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              Override command to pass after the image reference when running
              `dgoss run`. Empty string (the default) lets the image's own
              entrypoint/cmd drive the container; in that mode the
              `--entrypoint ""` flag is NOT passed. Set this to e.g.
              `"kubectl version"` only if you explicitly want to override the
              entrypoint and your image ships that binary.
            '';
            example = "sh -c 'sleep infinity'";
          };
        };
    };
}
