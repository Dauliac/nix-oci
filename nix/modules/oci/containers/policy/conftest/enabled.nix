# Container policy.conftest.enabled option
{
  lib,
  config,
  ...
}:
let
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { pkgs, ... }:
        {
          options.policy.conftest.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable OCI image config policy checking with Conftest.";
            default = cfg.oci.policy.conftest.enabled;
            defaultText = lib.literalExpression "config.oci.policy.conftest.enabled";
          };
          config._tests.policy-conftest-enabled = {
            level = "eval";
            default = {
              package = pkgs.hello;
            };
            override = {
              package = pkgs.hello;
              policy.conftest.enabled = true;
            };
          };
        };
    };
}
