# Example: NixOS deploy -- performance-tuned HTTP server.
#
# Demonstrates the performance module options:
#   - jemalloc allocator with container-safe defaults (muzzy_decay_ms:0)
#   - glibc tunables preset (balanced)
#   - deploy-time cgroup v2 controls (memoryHigh, cpuWeight, oomScoreAdj)
#   - network sysctl preset (web-server)
#   - log driver selection (passthrough)
{ pkgs, ... }:
let
  http-server = pkgs.writeShellApplication {
    name = "perf-http-server";
    runtimeInputs = [ pkgs.python3Minimal ];
    text = ''
      cd /var/www
      exec python3 -m http.server 8081
    '';
  };
in
{
  oci = {
    enable = true;
    backend = "podman";
    containers.perf-server = {
      package = http-server;
      dependencies = [
        pkgs.coreutils
        (pkgs.writeTextDir "var/www/index.html" "nix-oci-perf-ok\n")
      ];
      # nixosConfig triggers the NixOS eval pipeline where build-time
      # performance options (allocator, tunables) are applied to the image.
      # Must be non-empty to activate the eval (empty [] is a no-op).
      nixosConfig.modules = [ { } ];
      autoStart = true;
      ports = [ "8081:8081" ];

      # -- Build-time performance (baked into OCI image) --
      performance = {
        enable = true;
        allocator = "jemalloc";
        allocatorConfig = {
          "narenas" = "2";
          "dirty_decay_ms" = "5000";
        };
        glibcTunablesPreset = "balanced";
      };

      # -- Deploy-time runtime performance --
      performance.runtime = {
        memory = "512M";
        memoryHigh = "400M";
        cpuWeight = 200;
        oomScoreAdj = -100;
        networkPreset = "web-server";
        logDriver = "passthrough";
        tmpfsMounts = [
          "/tmp:rw,noexec,nosuid,size=32m"
        ];
      };
    };
  };
}
