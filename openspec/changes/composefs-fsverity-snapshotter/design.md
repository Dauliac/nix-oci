## Context

See proposal.md - Why. Grounding:

- composefs mounts an EROFS metadata image over a content-addressed backing store; optional per-file fs-verity measurement gives kernel-enforced integrity on `read()`.
- composefs is in-tree from kernel 6.6; NixOS 24.11+ default kernels satisfy this.
- fs-verity requires backing FS support: ext4 with the `verity` feature or btrfs >= 5.15. ZFS, xfs, tmpfs: unsupported.
- podman >= 4.6 supports composefs as a storage-driver mode via `use_composefs = "true"` under `[storage.options.overlay]` in `storage.conf`. Pinned `podman 5.7` clears this.
- Existing snapshotter option tree at `nix/modules/deploy/nix-oci/options/_snapshotter/{soci,stargz,zstd-chunked}/` is extensible; composefs slots in as a fourth sibling.
- Existing `mkStorageConf` in `nix/modules/deploy/nix-oci/options/_snapshotter/_lib.nix:80-88` is the drop-in-writer we extend.

## Goals / Non-Goals

**Goals:**
- Complete the pull-time-to-read-time integrity chain: sigstore verifies "the layer I pulled is what the publisher signed"; fs-verity verifies "the layer on disk right now is still what I pulled".
- Cheap deploy-side opt-in: enabling composefs is a single option flip, with kernel/FS assertions that catch mismatches at eval time.
- Coexistence with SOCI, stargz, zstd:chunked without silent conflicts.

**Non-Goals:**
- Producer-side changes. composefs digests are pull-time-computed from layer content; no image-spec change.
- fs-verity signing keys (out-of-tree in-kernel key management). This change enforces integrity of what was pulled; it does not tie fs-verity to sigstore keys.
- Migration of existing `/var/lib/containers` filesystems to a fs-verity-capable FS. Documented; not automated.

## Decisions

### `oci.snapshotter.composefs.enable` (bool) and `.fsVerity` (bool)

Two options rather than one to allow composefs without fs-verity (still gives content-addressed on-disk dedup) or fs-verity opt-out on hosts where the operator has other reasons to disable. Default: `enable = false`, `fsVerity = true` when enable is true.

### Kernel + filesystem assertions at eval time

The assertion checks (a) `boot.kernelPackages.kernel.version` (parseable), (b) `fileSystems."/var/lib/containers".fsType` (queryable in NixOS module context), and fails cleanly with actionable messages otherwise. Alternative: runtime probe. Rejected because eval-time failure is cheaper than surfacing a runtime error on first container start.

### storage.conf drop-in shape

Emit a single file `/etc/containers/storage.conf.d/composefs.conf` containing:
```
[storage.options.overlay]
use_composefs = "true"
```
plus any required `mount_program` if podman warrants it. Alternative: modify the main `storage.conf`. Rejected because drop-ins are the pattern already used by zstd:chunked in `_snapshotter/_lib.nix`.

### Coexistence semantics

Enabling composefs does not disable SOCI, stargz, or zstd:chunked. Their drop-in files coexist under `/etc/containers/storage.conf.d/`. podman merges the fragments at start-up. Alternative: enforce mutual exclusion. Rejected because SOCI lazy pull + composefs on-disk are complementary and users benefit from both.

## Risks / Trade-offs

- **fs-verity rejection at pull** -> if fs-verity is required and the layer fails measurement, podman rejects the pull with a clear error; documented remediation.
- **backing FS constraint** -> ZFS and xfs users cannot enable fs-verity; documented, with btrfs-migration or ext4-migration as recommended paths.
- **Kernel version drift** -> composefs is in-tree from 6.6; the eval-time assertion catches older kernels.
- **Podman version drift** -> `use_composefs` requires podman >= 4.6; assertion covers.

## Migration Plan

1. Ship with `enable = false` default.
2. Documentation walks through enabling on a fresh NixOS deploy: option flip, kernel confirmation, storage.conf drop-in appears.
3. For hosts on unsupported FS, migration is a separate operational effort (out of scope).

## Open Questions

None material.
