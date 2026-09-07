# Shared test helpers for nix-oci.
#
# Provides reusable builders so each test category (unit, vm, e2e)
# can declare checks with minimal boilerplate.
{
  pkgs,
  lib,
}:
{
  # Wrap a NixOS VM test with standard resource defaults.
  # Accepts the same args as pkgs.testers.runNixOSTest, but injects
  # sensible virtualisation defaults (cores, memory, disk, podman).
  mkVMTest =
    {
      name,
      nodes,
      testScript,
      ...
    }@args:
    pkgs.testers.runNixOSTest (
      lib.recursiveUpdate
        {
          inherit name testScript;
          nodes = lib.mapAttrs (
            _: nodeCfg:
            {
              pkgs,
              lib,
              ...
            }:
            lib.recursiveUpdate {
              # ── QEMU / virtualisation ───────────────────────────────
              # References:
              #   https://determinate.systems/blog/qemu-fix/
              #   https://nixcademy.com/posts/nixos-integration-tests-part-2/
              #   https://linus.schreibt.jetzt/posts/qemu-9p-performance.html
              virtualisation = {
                cores = 8;
                memorySize = 4096;
                # The app-tests VM loads ~20 example images sequentially,
                # each writing 400-800 MB to /var/lib/containers/storage
                # (podman) and /var/lib/docker (docker). 8 GB fills up
                # mid-run and later loads die with:
                #   error: no space left on device
                # 32 GB gives headroom for the cumulative image set.
                diskSize = 32768;
                # Disable graphical output — headless tests don't need a GPU.
                graphics = false;
                # Increase 9p max packet size: default 16384 → 131072.
                # Larger packets = fewer round-trips for store reads.
                # (see qemu-vm.nix: "Increasing this should increase
                # performance significantly, at the cost of higher RAM usage")
                msize = 131072;
              };

              documentation.enable = false;

              # ── Boot speed: initrd ────────────────────────────────
              # lz4 decompresses ~4x faster than zstd; saves ~0.5-1s on initrd load.
              boot.initrd.compressor = "lz4";
              boot.initrd.compressorArgs = [ "-l" ];

              # ── Boot speed: kernel ──────────────────────────────────
              # Test instrumentation forces loglevel=7; override to 4 (warnings).
              boot.consoleLogLevel = lib.mkForce 4;
              boot.kernelParams = [
                # Skip CPU vulnerability mitigations — not needed in test VMs.
                # Saves ~0.5s of mitigation setup and ongoing overhead.
                "mitigations=off"
                # Disable audit subsystem at boot
                "audit=0"
              ];

              # Blacklist unused hardware modules (floppy, parallel port, GPU, etc.)
              boot.blacklistedKernelModules = [
                "floppy"
                "bochs_drm"
                "parport"
                "parport_pc"
                "ppdev"
                "pcspkr"
                "snd_pcsp"
              ];

              # ── Boot speed: systemd / services ──────────────────────
              # Disable audit daemon (saves ~0.5s of audit init + journald overhead).
              security.audit.enable = false;

              # Disable services not needed in ephemeral test VMs.
              systemd.services.systemd-journal-flush.enable = false;
              systemd.services.systemd-update-utmp.enable = false;
              services.nscd.enable = false;
              system.nssModules = lib.mkForce [ ];
              # Nix daemon is useless inside test VMs — we never build inside them.
              nix.enable = false;

              # No swap overhead in test VMs.
              boot.kernel.sysctl."vm.swappiness" = 0;

              # Don't block boot waiting for DHCP lease — the test network
              # (eth1) uses static IPs from the test driver, and eth0's
              # DHCP is wasted effort (internet is blocked anyway).
              # "background" lets dhcpcd start without blocking boot.
              networking.dhcpcd.wait = "background";
            } (if builtins.isFunction nodeCfg then nodeCfg { inherit pkgs lib; } else nodeCfg)
          ) nodes;
        }
        (
          builtins.removeAttrs args [
            "name"
            "nodes"
            "testScript"
          ]
        )
    );
}
