{
  package = pkgs.busybox;
  hardening = {
    enable = true;
    seccomp = {
      enable = true;
      profile = "web-server";
      mode = "enforce";
    };
  };
}
