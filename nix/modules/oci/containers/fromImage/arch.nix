# Container fromImage.arch option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { system, ... }:
        {
          options.fromImage.arch = lib.mkOption {
            type = lib.types.enum [
              "amd64"
              "arm64"
            ];
            description = "The architecture of the image.";
            example = "amd64";
            default =
              if system == "x86_64-linux" then
                "amd64"
              else if system == "aarch64-linux" then
                "arm64"
              else
                throw "Unsupported system: ${system} as default arch, please set the arch option.";
            defaultText = lib.literalExpression ''
              if system == "x86_64-linux" then
                "amd64"
              else if system == "aarch64-linux" then
                "arm64"
              else
                throw "Unsupported system: ''${system} as default arch, please set the arch option."
            '';
          };
        };
    };
}
