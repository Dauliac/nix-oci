## 1. Option surface

- [ ] 1.1 Create `nix/modules/oci/containers/_options/hardening/systemd/restrict-network-interfaces.nix` (list of strings); verify option accessible via `nix eval`
- [ ] 1.2 Create `nix/modules/oci/containers/_options/hardening/systemd/protect-hostname.nix` (bool, default false); verify
- [ ] 1.3 Create `nix/modules/oci/containers/_options/hardening/systemd/restrict-filesystems.nix` (list of strings including systemd fstype groups); verify
- [ ] 1.4 Create `nix/modules/oci/containers/_options/hardening/systemd/protect-proc.nix` (enum, default `"invisible"`); verify

## 2. Emitter wiring

- [ ] 2.1 Extend `nix/modules/deploy/nix-oci/nixos/run-services.nix` to fold each new option into the `[Service]` block; verify emitted Quadlet contains the directives
- [ ] 2.2 Extend `nix/modules/deploy/nix-oci/home-manager/run-services.nix` similarly, respecting rootless limitations; verify emitted user Quadlet

## 3. Assertions

- [ ] 3.1 Add assertion in `nix/modules/deploy/nix-oci/nixos/_config/assertions.nix` that host `systemd` version >= 250 when any new directive is enabled; verify assertion message on a synthetic older-systemd config

## 4. BDD tests

- [ ] 4.1 Add `nix/modules/oci/containers/_tests/hardening/systemd/restrict-network-interfaces.test.nix`: directive appears, external interface blocked at runtime; verify in VM
- [ ] 4.2 Add `.../protect-hostname.test.nix`: `sethostname` inside container returns EPERM; verify in VM
- [ ] 4.3 Add `.../restrict-filesystems.test.nix`: mount outside whitelist fails; verify in VM
- [ ] 4.4 Add `.../protect-proc.test.nix`: other-user `/proc` entries invisible; verify in VM

## 5. Documentation

- [ ] 5.1 Add "systemd unit hardening" subsection to `docs/content/security/hardening.md` with per-directive rootless behavior notes; verify by rendering the docs site locally
