{
  package = pkgs.nginx;
  hardening.capabilities = {
    drop = [ "ALL" ];
    add = [ "NET_BIND_SERVICE" ];
  };
}
