{
  package = pkgs.busybox;
  isRoot = true;
  hardening = {
    enable = true;
    disableDns = true;
    noTlsTrustStore = true;
    seccomp = {
      enable = true;
      profile = "strict";
    };
    capabilities = {
      drop = [ "ALL" ];
      add = [ "NET_BIND_SERVICE" ];
    };
    readOnlyRootfs = true;
    noNewPrivileges = true;
  };
}
