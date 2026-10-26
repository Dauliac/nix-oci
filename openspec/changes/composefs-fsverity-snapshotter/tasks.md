## 1. Option surface

- [ ] 1.1 Create option tree `nix/modules/deploy/nix-oci/options/_snapshotter/composefs/{enable,fs-verity}.nix`; verify option surface via `nix eval`

## 2. storage.conf drop-in

- [ ] 2.1 Extend `mkStorageConf` in `nix/modules/deploy/nix-oci/options/_snapshotter/_lib.nix:80-88` to emit `use_composefs = "true"` under `[storage.options.overlay]` when composefs is enabled; verify emitted drop-in contents
- [ ] 2.2 Extend `nix/modules/deploy/nix-oci/nixos/snapshotter.nix:76-79` to wire the composefs branch alongside existing zstd:chunked; verify all branches coexist

## 3. Assertions

- [ ] 3.1 Add kernel-version assertion (`boot.kernelPackages.kernel.version >= 6.6`) when composefs enabled; verify assertion on synthetic old-kernel config
- [ ] 3.2 Add filesystem-support assertion (`/var/lib/containers` FS in `{ ext4, btrfs }`) when fs-verity enabled; verify assertion on synthetic ZFS config

## 4. BDD test

- [ ] 4.1 Add `nix/modules/oci/containers/_tests/snapshotter/composefs.test.nix` with scenarios: drop-in emitted, container starts, post-pull byte modification causes next read to return EIO; verify all pass in VM harness with fs-verity-enabled ext4 image (VM harness may need updating to boot with the right kernel config; document)

## 5. Documentation

- [ ] 5.1 Write `docs/content/security/on-disk-integrity.md` covering composefs, fs-verity, kernel/FS requirements, and the trust chain from build to disk; verify by rendering the docs site locally
