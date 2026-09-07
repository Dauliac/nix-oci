{
  lib,
  pkgs,
  ...
}:
{
  # Upstream nixpkgs (nixos-25.11 pin) resolves `boot.initrd.compressor = "lz4"`
  # to `${pkgs.lz4.dev}/bin/lz4` — but the `-dev` output only ships headers
  # and libs, not the binary. make-initrd aborts with:
  #   /nix/store/…-lz4-1.10.0-dev/bin/lz4: No such file or directory
  # Point at the main (`out`) output which does ship `bin/lz4`. Keep the
  # `-l` flag NixOS defaults for lz4 (legacy format the kernel decoder wants).
  boot.initrd.compressor = lib.mkForce "${lib.getBin pkgs.lz4}/bin/lz4";
  boot.initrd.compressorArgs = lib.mkForce [ "-l" ];
}
