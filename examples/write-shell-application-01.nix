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
          write-shell-application = {
            package = pkgs.writeShellApplication {
              name = "hello-app";
              runtimeInputs = [ pkgs.coreutils ];
              text = ''
                echo "Hello from writeShellApplication!"
                whoami
              '';
            };
          };
        };
      };
  };
}
