# BDD test specs for environment option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.environment = {
        eval-defaults = {
          given = "a container with no environment variables";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with empty environment";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };

        inspect-custom-env = {
          given = "a container with custom environment variables";
          "when" = "the OCI image is inspected";
          "then" = "the environment variables are present in image config";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            environment = {
              FOO = "bar";
              DEBUG = "1";
            };
          };
          assertions.imageConfig.Env = [
            "FOO=bar"
            "DEBUG=1"
          ];
        };

        runtime-env-visible = {
          given = "a container with environment variable MY_VAR=hello";
          "when" = "the container process environment is read";
          "then" = "MY_VAR is present with value hello";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            entrypoint = [
              "${pkgs.busybox}/bin/busybox"
              "sh"
              "-c"
              "cat /proc/1/environ"
            ];
            environment.MY_VAR = "hello";
          };
          assertions.processEnv.MY_VAR = "hello";
        };
      };
    };
}
