## 1. Option surface

- [ ] 1.1 Create `nix/modules/oci/containers/_options/devices/cdi.nix` (list of CDI device reference strings); verify option accessible via `nix eval`

## 2. Emitter wiring

- [ ] 2.1 Extend the podman emitter (`nix/modules/oci/podman/lib.nix` or the deploy `run-services.nix` files) to emit `--device <cdi-ref>` per list entry; verify emitted `podman run` invocation
- [ ] 2.2 Extend Quadlet emission to include `AddDevice=<cdi-ref>` per entry in the `[Container]` block; verify emitted Quadlet

## 3. Test fixture

- [ ] 3.1 Add `nix/modules/oci/testing/fixtures/cdi-fake.json` describing a synthetic device (`example.com/widget=all`) with a bind mount of a marker file; verify the JSON validates against the CDI spec via `nvidia-ctk cdi validate` or equivalent

## 4. BDD test

- [ ] 4.1 Add `nix/modules/oci/containers/_tests/devices/cdi.test.nix` with scenarios: `--device` flag emitted, Quadlet key present, container starts with fake CDI spec on VM `/etc/cdi/`, marker file present inside container; verify all pass in VM harness

## 5. Documentation

- [ ] 5.1 Write `docs/content/reference/container-devices.md` covering CDI syntax, host availability requirements, and a "Migrating from legacy NVIDIA env-var" section with before/after example; verify by rendering the docs site locally
- [ ] 5.2 Mark the legacy `oci.container.gpu.*` env-var path deprecated in `nix/modules/oci/containers/_options/gpu/enable.nix` documentation comment; verify by grepping for the deprecation note
