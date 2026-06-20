{
  package = pkgs.hello;
  hardening.landlock = {
    enable = true;
    allowedReadPaths = [
      "/etc"
      "/nix/store"
    ];
    allowedWritePaths = [ "/tmp" ];
    allowedTcpConnect = [ 443 ];
  };
}
