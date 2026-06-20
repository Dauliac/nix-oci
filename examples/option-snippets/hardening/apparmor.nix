{
  package = pkgs.hello;
  hardening.apparmor = {
    enable = true;
    mode = "enforce";
    denyMount = true;
    denyPtrace = true;
  };
}
