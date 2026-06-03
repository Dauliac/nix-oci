# Derive container tag from package version or base image tag
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCITag = {
    type = lib.types.functionTo lib.types.str;
    description = "Derive container tag from package version or base image tag";
    fn =
      {
        package,
        fromImage,
      }:
      let
        version = if package != null then package.version or "" else "";
        hasVersion = version != null && version != "";
      in
      if hasVersion then
        version
      else if fromImage.enabled && fromImage.imageTag != null then
        fromImage.imageTag
      else
        "latest";
    tests = {
      "derives tag from package version" = {
        args = {
          package = {
            version = "1.2.3";
          };
          fromImage = {
            enabled = false;
          };
        };
        expected = "1.2.3";
      };
      "falls back to latest when package has empty version" = {
        args = {
          package = {
            version = "";
          };
          fromImage = {
            enabled = false;
          };
        };
        expected = "latest";
      };
      "falls back to latest when package has no version attribute" = {
        args = {
          package = {
            name = "my-script";
          };
          fromImage = {
            enabled = false;
          };
        };
        expected = "latest";
      };
      "derives tag from fromImage when package has no version" = {
        args = {
          package = null;
          fromImage = {
            enabled = true;
            imageTag = "latest";
          };
        };
        expected = "latest";
      };
      "falls back to latest when neither package nor fromImage provide tag" = {
        args = {
          package = null;
          fromImage = {
            enabled = false;
          };
        };
        expected = "latest";
      };
    };
  };
}
