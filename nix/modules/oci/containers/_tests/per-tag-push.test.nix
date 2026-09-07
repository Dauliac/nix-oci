# BDD test specs for per-tag push filter (GH issue #10).
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.perTagPush = {
        eval-default-push-inherits-container = {
          given = "a container with push=true and no per-tag override";
          "when" = "the container config is evaluated";
          "then" = "every tagConfig inherits push=true";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            push = true;
            tags = [
              "latest"
              "v1"
            ];
          };
        };

        eval-disable-one-tag = {
          given = "a container where a single tag has push=false";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and only enabled tags remain pushable";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            push = true;
            tags = [
              "latest"
              "v1"
              "v1.1"
            ];
            tagConfigs = {
              "v1.1".push = false;
            };
          };
        };

        eval-disable-primary-tag = {
          given = "a container where the primary tag has push=false";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and a secondary pushable tag is promoted";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            push = true;
            tags = [
              "latest"
              "v1"
            ];
            tagConfigs = {
              "latest".push = false;
            };
          };
        };

        eval-disable-all-tags = {
          given = "a container where every tag has push=false";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and the push app becomes a no-op";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            push = true;
            tags = [
              "latest"
              "v1"
            ];
            tagConfigs = {
              "latest".push = false;
              "v1".push = false;
            };
          };
        };
      };
    };
}
