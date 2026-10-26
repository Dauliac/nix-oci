# Shared NixOS node defaults for every nix-oci VM test.
#
# Historically these lived inline inside the `mkVMTest` function in
# `tests/lib.nix`, which forced every VM test to inherit the same
# monolith sizing (8 cores / 4 GiB / 32 GiB disk) and boot-speed
# tweaks. Moving them into a per-node NixOS module lets any VM test
# override one knob via standard module composition:
#
#   # inside a test node:
#   virtualisation.cores = lib.mkForce 4;
#   boot.kernelParams = lib.mkForce [ "mitigations=auto" ];
#
# without forking `mkVMTest`. The dendritic `_app-vm` module (also under
# `nix/modules/oci/testing/`) layers on top of this one with its own
# per-container-smoke sizing + `oci.testing.appVm.*` option surface.
#
# References:
#   https://determinate.systems/blog/qemu-fix/
#   https://nixcademy.com/posts/nixos-integration-tests-part-2/
#   https://linus.schreibt.jetzt/posts/qemu-9p-performance.html
{ lib, ... }:
{
  # ── QEMU / virtualisation ───────────────────────────────
  virtualisation = {
    cores = 8;
    memorySize = 4096;
    # The app-tests aggregate VM used to load ~20 example images
    # sequentially, each writing 400-800 MB to containers-storage
    # or docker. 8 GB filled up mid-run; 32 GB gives headroom for
    # the cumulative image set. Per-container `bdd-app-<name>` VMs
    # override this to 4 GB via the _app-vm module.
    diskSize = 32768;
    # Headless tests don't need a GPU.
    graphics = false;
    # Larger 9p packets = fewer round-trips for /nix/store reads.
    # Default is 16384; this is 8x, at the cost of more host RAM.
    # Per-container VMs override to 32768 to balance across many
    # concurrent guests at `--max-jobs N`.
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
    # Skip CPU vulnerability mitigations - not needed in test VMs.
    # Saves ~0.5s of mitigation setup and ongoing overhead.
    "mitigations=off"
    # Disable audit subsystem at boot.
    "audit=0"
  ];

  # Blacklist unused hardware modules.
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
  security.audit.enable = false;
  systemd.services.systemd-journal-flush.enable = false;
  systemd.services.systemd-update-utmp.enable = false;
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];
  # Nix daemon is useless inside test VMs - we never build inside them.
  nix.enable = false;

  # No swap overhead in test VMs.
  boot.kernel.sysctl."vm.swappiness" = 0;

  # Don't block boot waiting for DHCP lease - the test network
  # (eth1) uses static IPs from the test driver, and eth0's
  # DHCP is wasted effort (internet is blocked anyway).
  networking.dhcpcd.wait = "background";
}
