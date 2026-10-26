## Why

The pipeline verifies image integrity at pull time via cosign signatures. On-disk integrity after pull is not verified: a rootkit or a compromised host process can swap a layer file after extraction and every subsequent container start reads the tampered file. composefs (`https://github.com/containers/composefs`) mounts a read-only EROFS metadata image over a content-addressed backing store with optional fs-verity measurement, so the kernel enforces per-file cryptographic integrity on every `read()`. Podman 4.6+ supports composefs as a storage-driver mode; the pinned podman 5.7 clears this comfortably. This is the on-disk complement to sigstore verification: signing covers "the layer I pulled is the one the publisher signed", fs-verity covers "the layer on disk right now is still that layer".

## What Changes

- Add new snapshotter option tree `nix/modules/deploy/nix-oci/options/_snapshotter/composefs/`:
  - `enable.nix` (bool, default false)
  - `fs-verity.nix` (bool, default true when composefs is enabled)
- Extend `mkStorageConf` in `nix/modules/deploy/nix-oci/options/_snapshotter/_lib.nix:80-88` to emit `use_composefs = "true"` and any required `[storage.options.overlay]` keys when composefs is enabled.
- Extend `nix/modules/deploy/nix-oci/nixos/snapshotter.nix:76-79` to wire the composefs branch alongside the existing zstd:chunked branch.
- Add kernel/fs feasibility assertions in `nix/modules/deploy/nix-oci/nixos/_config/assertions.nix`:
  - `boot.kernelPackages.kernel.version` >= 6.6 (composefs in-tree)
  - `fileSystems."/var/lib/containers".fsType` in `{ ext4, btrfs }` (fs-verity supported); assert with actionable message otherwise.
- BDD test in a VM with fs-verity-enabled ext4: (a) `use_composefs = "true"` present in `/etc/containers/storage.conf.d/*.conf`; (b) container starts; (c) modifying a file in the extracted store after pull causes the next container read to fail with `EIO` (fs-verity enforcement).
- Docs: new `docs/content/security/on-disk-integrity.md` covering composefs, fs-verity, and the sigstore complement.

## Capabilities

### New Capabilities
- `deploy/snapshotter-composefs`: deploy-side storage driver enabling composefs + fs-verity, bridging pull-time sigstore verification with read-time kernel-enforced integrity.

### Modified Capabilities
None (existing snapshotter tree adds a sibling, does not modify siblings).

## Impact

- Depends on host kernel >= 6.6 and a fs-verity-capable backing filesystem; assertions catch mismatches early.
- No producer-side change (composefs digests are computed at pull time from layer content; no image-spec change).
- Composes with `sigstore-bundle-format` (pull-time verify) and `slsa-provenance-predicate` (build-time verify) as a "trust chain from build to disk" story.
- Composefs is also the natural storage backend for future zstd:chunked layer support (currently deferred in the roadmap).
