# Container policy.conftest.namespaces option
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
          options.policy.conftest.namespaces = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Rego namespaces to check.";
            default = cfg.oci.policy.conftest.namespaces;
            defaultText = lib.literalExpression "config.oci.policy.conftest.namespaces";
            example = [
              "main"
              "custom"
            ];
          };
          config._tests.policy-conftest-namespaces = {
            level = "eval";
            default = {
              package = pkgs.hello;
            };
            override = {
              package = pkgs.hello;
              policy.conftest.namespaces = [
                "main"
                "custom"
              ];
            };
          };
        };
    };
}
