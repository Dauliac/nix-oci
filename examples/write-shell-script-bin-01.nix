{ ... }:
{
  config = {
    perSystem =
      {
        pkgs,
        config,
        ...
      }:
      {
        config.oci.containers = {
          write-shell-script-bin = {
            package = pkgs.writeShellScriptBin "hello-script" ''
              echo "Hello from writeShellScriptBin!"
            '';
          };
        };
      };
  };
}
