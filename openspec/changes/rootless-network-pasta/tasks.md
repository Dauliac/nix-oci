## 1. Option surface

- [ ] 1.1 Create `nix/modules/oci/containers/_options/network/rootless-backend.nix` with enum `"pasta" | "slirp4netns"`, default `"pasta"`; verify option accessible via `nix eval`

## 2. Emitter wiring

- [ ] 2.1 Extend `nix/modules/deploy/nix-oci/home-manager/run-services.nix` to append `--network=<backend>` (or the Quadlet `Network=<backend>` key when supported); verify emitted quadlet contains the correct key
- [ ] 2.2 Extend `nix/modules/deploy/nix-oci/nixos/run-services.nix` similarly for uid-mapped services (root-owned containers unaffected); verify emitted unit

## 3. Assertions

- [ ] 3.1 Add assertion that host `podman` version >= 5.0 when `pasta` selected; verify assertion message on a synthetic older-podman config

## 4. BDD tests

- [ ] 4.1 Add `nix/modules/oci/containers/_tests/network/rootless-backend.test.nix` with scenarios: pasta selected emits `--network=pasta`, slirp4netns selected emits the alternative, port forwarding works under both; verify all pass in VM harness

## 5. Documentation

- [ ] 5.1 Extend `docs/content/how-to/nixos-containers.md` (or create `how-to/rootless-networking.md`) with a pasta vs slirp4netns trade-off table (throughput, syscall surface, host requirements); verify by rendering the docs site locally
