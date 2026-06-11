# Shared container definitions for image structure tests.
#
# Used by both NixOS (structure.nix) and system-manager
# (structure-system-manager.nix) backends.
{ pkgs }:
{
  minimalist = {
    package = pkgs.kubectl;
    user = "kubectl";
  };
  minimalist-with-deps = {
    package = pkgs.kubectl;
    user = "kubectl";
    dependencies = [
      pkgs.bash
      pkgs.kubectl-cnpg
    ];
  };
  minimalist-with-name = {
    name = "hola";
    package = pkgs.hello;
    user = "hello";
  };
  with-root-user = {
    package = pkgs.bash;
    dependencies = [ pkgs.coreutils ];
    isRoot = true;
  };
  write-shell-script-bin = {
    package = pkgs.writeShellScriptBin "hello-script" ''
      echo "Hello from writeShellScriptBin!"
    '';
    user = "hello-script";
  };
  write-shell-application = {
    package = pkgs.writeShellApplication {
      name = "hello-app";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        echo "Hello from writeShellApplication!"
        whoami
      '';
    };
    user = "hello-app";
  };
}
