# Shared container definitions for hardening tests.
#
# Used by both NixOS (hardening.nix) and system-manager
# (hardening-system-manager.nix) backends.
{
  pkgs,
  tryIoUring,
}:
{
  hardening-dns-disabled = {
    package = pkgs.busybox;
    isRoot = true;
    optimizeLayers = true;
    hardening = {
      enable = true;
      disableDns = true;
    };
  };
  hardening-no-tls = {
    package = pkgs.busybox;
    isRoot = true;
    optimizeLayers = true;
    hardening = {
      enable = true;
      noTlsTrustStore = true;
    };
  };
  hardening-full = {
    package = pkgs.busybox;
    isRoot = true;
    optimizeLayers = true;
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
  };
  hardening-seccomp-enforce = {
    package = tryIoUring;
    isRoot = true;
    dependencies = [ pkgs.busybox ];
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        profile = "moderate";
      };
    };
  };
  hardening-database = {
    package = pkgs.busybox;
    isRoot = true;
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        profile = "database";
      };
    };
  };
  hardening-audit = {
    package = pkgs.busybox;
    isRoot = true;
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        profile = "strict";
        mode = "audit";
      };
    };
  };
}
