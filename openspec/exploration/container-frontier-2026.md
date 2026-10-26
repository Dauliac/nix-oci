+++
title = "Container frontier 2026"
description = "Ideas at the edge of container supply chain, hardening, and runtime that nix-oci does not yet cover, with primary sources and fit assessments"
+++

# Container frontier 2026

Scope: identify capabilities from the OCI, CNCF, SLSA, sigstore, in-toto,
kernel, and container-runtime ecosystems that nix-oci does not obviously
cover today. For every proposal: what it is, primary source, why it is
edge, fit into the existing architecture (pipeline step, `oci.container.*`
option, backend, or doc/architecture), and rough effort.

Primary sources only. Where a specification exists, it is preferred over
any implementation blog or vendor material. Claims without a primary
source are dropped.

## Rejected: already covered

The following were considered and rejected because the project already
implements them (per project memory and `docs/content/architecture/`):

- **SBOM generation (syft, SPDX/CycloneDX 1.5)**: covered by the SBOM
  pipeline category.
- **Sigstore keyed and keyless signing (cosign sign)**: covered by the
  signing category (`oci.signing.cosign.*`).
- **CVE scanning (trivy, grype, vulnix)**: covered by the CVE category.
- **Rego policy on manifests (conftest with `oci.rego` + user policy
  dirs)**: covered by `oci.policy.conftest.*`.
- **Container-structure-test with metadataTest**: covered by
  `mkCoherenceCst` and `oci.test.containerStructureTest.*`.
- **Runtime probes (amicontained, CDK, DEEPCE, linPEAS, dive, dgoss)**:
  covered by `oci.test.{amicontained,cdk,deepce,linpeas,dive,dgoss}.*`.
- **Seccomp, no-new-privs, drop-caps, read-only rootfs, AppArmor, TLS
  trust-store scrub, non-root user, setuid removal**: covered by the
  hardening category (`oci.container.hardening.*`).
- **Allocator swap, glibc tunables, hwcaps, ulimits, cgroups (mem/cpu/io/
  pids), logging limits**: covered by the performance category
  (`oci.container.performance.*`).
- **GPU capabilities, CUDA version pin, runtime libs, forward-compat**:
  covered by `oci.container.gpu.*`.
- **SOCI v2 lazy pull + turbo cross-machine layer cache**: covered by
  `nix2container-turbo` backend and the deploy-side snapshotter service.
- **Auto-generated OCI labels (`org.opencontainers.image.*`)**: covered
  by `automatic-labeling.md`.
- **Reproducible tarball-less layers (nix2container)**: this is the
  substrate, not a proposal.
- **Rootless podman quadlets (home-manager)**: already generated.
- **`cosign attest` with SBOM predicate**: available via the signing +
  SBOM steps; the delta below is about *what predicate* to attach.
- **`podman generate systemd` deprecation**: quadlets already the target;
  no action.
- **Kubernetes admission (Kyverno, Gatekeeper) on the built image**: out
  of scope for an image builder; those run cluster-side.

The following were considered and rejected because the primary source
was insufficient or the technology is dead-ended:

- **botb (Break-out-The-Box)**: last release 2021, CDK covers the same
  scope. Confirmed by project memory.
- **Compiler flag knobs (`-march`, LTO, `-O3`) on `oci.container.*`**:
  memory records these as explicitly out of scope, they belong at the
  package layer.
- **`podman generate systemd` support**: officially deprecated, replaced
  by Quadlets which the project already emits.
- **UOR (Universal Object Reference)**: no primary spec repository
  reachable; not standardized under OCI.
- **botb, `docker-bench-security`**: dgoss / dockle already cover.

Everything below is *not* in the reject list.

---

## 1. Supply-chain provenance beyond SBOM + sign

### 1.1 SLSA v1.0/v1.1 build provenance predicate (in-toto)

- **What.** A signed in-toto attestation with the SLSA `provenance`
  predicate describing `buildDefinition` (buildType, externalParameters,
  resolvedDependencies) and `runDetails` (builder, metadata,
  byproducts). Consumers use it to verify an artifact came from an
  expected builder invoked with expected inputs.
- **Primary source.**
  <https://slsa.dev/spec/v1.1/provenance>,
  <https://slsa.dev/spec/v1.1/levels>,
  <https://github.com/in-toto/attestation/tree/main/spec/predicates>.
- **Why edge.** The current signing step signs the image and can attest
  an SBOM predicate. It does not yet emit a SLSA provenance predicate
  describing the *Nix build* (flake ref, revision, `nixpkgs` locked
  input hashes, hydra/CI builder identity). Without provenance, a
  consumer cannot distinguish an image built from a tagged flake input
  set on a hardened CI runner from one built from a dirty local tree.
- **Delta vs existing.** Signing exists. Attestation of an SBOM
  predicate exists. What is missing is a *SLSA provenance* predicate
  generator that consumes `flake.lock`, the flake ref, and the
  substituter/builder identity, and emits the in-toto Statement for the
  image digest.
- **SLSA level reachable.** Nix builds satisfy L1 by construction
  (reproducible, inputs recorded in `flake.lock`). L2 requires the
  build platform to sign the provenance (i.e. keyless cosign from a CI
  identity, not the local user). L3 requires isolation of signing key
  material from user-defined build steps; achievable on GitHub Actions
  via OIDC or on a dedicated Nix builder with sealed key material.
- **Fit.** New pipeline step `oci.pipeline.steps.slsaProvenance` in the
  `provenance` category, output attached as a cosign attestation.
- **Effort.** Medium. Predicate is a well-defined JSON schema; the work
  is deriving `resolvedDependencies` from `flake.lock` outputs and
  wiring a `builder.id` option.

### 1.2 GitHub Artifact Attestations as second-signer

- **What.** GitHub-native attestations bind an artifact digest to a
  SLSA v1.0 provenance predicate, signed with a short-lived Sigstore
  certificate keyed to the workflow identity; verified with
  `gh attestation verify`.
- **Primary source.**
  <https://github.com/actions/attest-build-provenance>.
- **Why edge.** For projects that CI on GitHub, this is an
  L2-reachable, zero-config second signer independent of the user's
  cosign key. A consumer with only `gh` installed can verify.
- **Fit.** Pipeline step under `provenance/github-attest`, active only
  when `oci.pipeline.builder = "github-actions"`; no new option surface
  otherwise.
- **Effort.** Small. Calls `actions/attest-build-provenance` in CI, no
  build-time work.

### 1.3 GUAC as SBOM + attestation ingest target

- **What.** Graph for Understanding Artifact Composition ingests SPDX,
  CycloneDX, SLSA, in-toto, OSV, CSAF/VEX, OpenVEX, and Scorecard data
  into a queryable graph.
- **Primary source.** <https://github.com/guacsec/guac>.
- **Why edge.** The pipeline emits SBOM + signature + (with 1.1)
  provenance + (with 1.5) VEX. Without a documented ingest path, users
  build a pile of blobs and no query surface. GUAC is the CNCF-blessed
  aggregation layer.
- **Fit.** Architecture doc, not code. A short `docs/content/how-to/
  guac-ingest.md` showing `guacone collect files` against the pipeline
  outputs. Optionally a pipeline step `provenance/guac-push` for users
  running a GUAC instance.
- **Effort.** Small (docs) to medium (push step).

### 1.4 OpenVEX documents (vulnerability exploitability exchange)

- **What.** JSON-LD documents stating whether a given CVE actually
  affects a given product, with status values (`not_affected`,
  `affected`, `fixed`, `under_investigation`) and justifications.
- **Primary source.** <https://github.com/openvex/spec>.
- **Why edge.** Trivy and grype produce raw CVE lists. Most reported
  CVEs are non-exploitable in the specific closure (unused code paths,
  compile-time-disabled features, sandboxed callers). Without VEX,
  ship-blocking scan noise is a treadmill; with VEX, the maintainer
  documents once ("`CVE-2025-XXXX` `not_affected` because `zlib` is
  linked but the vulnerable `inflateBack` path is unreachable") and
  scanners downstream honour it.
- **Fit.** Two changes: (a) new option
  `oci.container.security.vex.documents = [ ./vex/*.json ]` that gets
  packaged as a referrer of the image manifest, (b) pipeline step
  `provenance/vex-attach` that runs `vexctl attest` and attaches the
  document. Trivy and grype both consume OpenVEX natively.
- **Effort.** Medium. The Nix-authored VEX ergonomics (statements as
  attrsets) are the interesting design surface.

### 1.5 Sigstore protobuf bundle format

- **What.** A single-file bundle (`.sigstore.json`) containing the
  signature, the signing certificate, transparency-log inclusion
  proofs, and RFC3161 timestamps in a protobuf-defined schema.
- **Primary source.**
  <https://docs.sigstore.dev/about/bundle/>,
  <https://github.com/sigstore/protobuf-specs>.
- **Why edge.** Detached `.sig` + `.pem` + Rekor entry lookup is what
  cosign historically emitted. The bundle format is what newer verifier
  libraries (sigstore-python, sigstore-js, `gh attestation verify`)
  consume by default. If nix-oci emits only detached artifacts,
  downstream verifiers need a shim.
- **Fit.** Output option on the signing step:
  `oci.signing.cosign.bundleFormat = "bundle" | "detached"`. Cosign
  supports `--bundle` output directly.
- **Effort.** Small. Flag flip on the existing cosign invocation.

### 1.6 CycloneDX 1.6 cryptographic-asset inventory

- **What.** CycloneDX 1.6 adds the `cryptographic-asset` component type
  covering algorithms, protocols, certificates, keys, and related
  parameters, and expands ML-BOM and formulation coverage.
- **Primary source.** <https://cyclonedx.org/docs/1.6/json/>.
- **Why edge.** Post-quantum migration audits and FIPS-mode inventory
  work want a cryptographic-primitives inventory that the current
  syft-produced SBOM does not carry. For images shipping TLS,
  SSH, JOSE, or PGP tooling, this is where the ecosystem is going.
- **Fit.** Bump the syft output-format target to CycloneDX 1.6
  (`syft ... -o cyclonedx-json@1.6`) and expose
  `oci.container.sbom.syft.cryptoAssets = true` to enable the
  crypto-asset scan pass.
- **Effort.** Small. Syft ≥ 1.10 emits 1.6.

### 1.7 SPDX 3.0 AI/security profiles

- **What.** SPDX 3.0 splits into profiles: Core, Software, Security,
  Dataset, AI, Build. Adds `AIPackage`, `VulnAssessmentRelationship`
  (VEX-like), `DatasetPackage`.
- **Primary source.** <https://spdx.github.io/spdx-spec/v3.0.1/>.
- **Why edge.** For images that ship ML models or datasets, the AI
  profile is the standards-track answer to "model card as SBOM entry".
  For everything else, the Security profile duplicates OpenVEX at the
  SBOM layer.
- **Fit.** SBOM output option
  `oci.container.sbom.syft.spdxVersion = "2.3" | "3.0"` once syft
  ships 3.0 emit. Track upstream; do not fork.
- **Effort.** Small once syft supports it; watching-brief today.

### 1.8 SCAI (Supply Chain Attribute Integrity) predicate

- **What.** in-toto predicate for asserting *functional* attributes of
  an artifact (compiler flags used, static-analysis clean, hardware
  attestation of the build host) with pluggable evidence.
- **Primary source.**
  <https://github.com/in-toto/attestation/blob/main/spec/predicates/scai.md>.
- **Why edge.** SLSA provenance says "built by X with inputs Y". SCAI
  says "the resulting binary was compiled with `-fstack-protector-all`,
  was passed by `syzkaller` for N hours, was built inside a TEE
  measured to PCR value Z". It is the standardised place to publish
  build-time hardening posture, which is exactly what a Nix builder
  can prove that a Dockerfile builder cannot.
- **Fit.** Pipeline step `provenance/scai` that harvests
  `oci.container.hardening.*` and `performance.*` config into SCAI
  attribute assertions, signed and attached as a referrer.
- **Effort.** Medium. The interesting work is a Nix → SCAI mapping
  table for the existing hardening/performance options.

---

## 2. New runtime hardening surfaces

### 2.1 Landlock LSM self-restriction (kernel ≥ 5.13)

- **What.** Unprivileged LSM that lets a process voluntarily restrict
  its own filesystem and network access without `CAP_SYS_ADMIN`. Only
  requires `no_new_privs` set (which containers usually set anyway).
- **Primary source.**
  <https://docs.kernel.org/userspace-api/landlock.html>,
  <https://landlock.io/>.
- **Why edge.** Seccomp restricts syscalls; AppArmor requires a
  privileged loader; SELinux requires a labelled policy. Landlock is
  the only ambient-rights restriction that works inside an
  unprivileged rootless container without host cooperation. For
  entrypoints written in languages with Landlock bindings (Rust
  `landlock` crate, Go `landlock-lsm/go-landlock`), the image can
  ship a small wrapper that self-restricts before `exec`ing the app.
- **Fit.** New option `oci.container.hardening.landlock = {
  enable, readOnlyPaths, readWritePaths, restrictNetwork }` that
  generates a small static wrapper (`landlock-wrap`) placed as the
  entrypoint. Complementary to seccomp, not a replacement.
- **Effort.** Medium. Wrapper is small; option modelling is the work.

### 2.2 Newer systemd unit hardening directives for Quadlets

- **What.** systemd ≥ 250 adds `RestrictNetworkInterfaces=`
  (whitelist named interfaces), `ProtectHostname=` (blocks
  `sethostname`/`setdomainname`), `RestrictFileSystems=` (whitelist
  fstype families like `@network`), and `ProtectProc=invisible` (hide
  other users' `/proc` entries).
- **Primary source.** `systemd.exec(5)` at
  <https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html>.
- **Why edge.** The generated Quadlets set the basics (`NoNewPrivileges`,
  `PrivateTmp`, `ProtectSystem`) but not this newer set. On distros
  shipping systemd ≥ 250 (Fedora 36+, RHEL 9.4+, Debian 12+ backport,
  most current NixOS), these directives are free defence-in-depth.
- **Fit.** Extend the Quadlet emitter in
  `nix/modules/deploy/nix-oci/nixos/` with a
  `oci.container.hardening.systemd.*` option map that gates each
  directive; default-off with per-directive opt-in until the deploy
  test matrix covers the older-systemd fallback path.
- **Effort.** Small per directive; larger if we cover the whole
  `systemd.exec` sandboxing surface.

### 2.3 CDI (Container Device Interface) for GPU/FPGA/TPM

- **What.** CNCF standard replacing runtime-specific device hooks
  (NVIDIA container-toolkit hook) with a declarative JSON/YAML
  device spec discoverable at `/etc/cdi/*.json`. Default in Docker
  ≥ 28.2, CRI-O default, containerd opt-in, podman ≥ 4.1.
- **Primary source.**
  <https://github.com/cncf-tags/container-device-interface>.
- **Why edge.** Current `oci.container.gpu.*` handles the image side.
  The deploy side still relies on the runtime's own device injection
  path, which is NVIDIA-specific. CDI is the standards-track answer,
  applies uniformly to GPU, FPGA, TPM, USB devices, and
  cleanly separates image-declared *requirements* from host-declared
  *availability*.
- **Fit.** New option
  `oci.container.devices.cdi = [ "nvidia.com/gpu=all" ]` that emits
  the `--device` CDI reference on `podman run` and the equivalent
  Quadlet `AddDevice=`.
- **Effort.** Small (option + emitter); test coverage in a VM with a
  fake CDI spec is the real cost.

### 2.4 Rootless networking: pasta over slirp4netns (podman ≥ 5)

- **What.** `pasta` (from the passt project) is a userspace L2/L4
  network translator: 4-50× IPv4 TCP throughput over slirp4netns,
  seccomp-locked to 43 syscalls on x86_64, all caps dropped except
  optional `CAP_NET_BIND_SERVICE`. Default rootless backend since
  podman 5.0.
- **Primary source.** <https://passt.top/passt/about/>.
- **Why edge.** For rootless home-manager quadlets, network perf and
  syscall surface both improve materially. Slirp4netns is the past.
- **Fit.** `oci.container.network.rootlessBackend = "pasta" | "slirp4netns"`
  with pasta as the default when the host podman ≥ 5.
- **Effort.** Small (option + validation).

### 2.5 crun WASM handler

- **What.** crun supports a WASM handler via
  `run.oci.handler=wasm` annotation. Runs `.wasm` binaries natively
  (auto-compiles `.wat`). Alternative to full runwasi + shim setup.
- **Primary source.** `crun.1.md` at
  <https://github.com/containers/crun/blob/main/crun.1.md>.
- **Why edge.** For workloads compiled to WASM/WASI (Rust with
  `wasm32-wasi`, TinyGo, AssemblyScript), a WASM image has near-zero
  syscall surface and no glibc/musl closure. Nix can produce the
  `.wasm` binary reproducibly today.
- **Fit.** `oci.container.runtime.handler = "wasm"` that (a) sets the
  annotation on the manifest, (b) validates entrypoint is `.wasm`,
  (c) strips glibc/musl closure. Composes with the existing hardening
  layer.
- **Effort.** Medium. Interesting design: how to prevent accidental
  inclusion of non-WASM binaries in the closure.

### 2.6 youki / gVisor (runsc) as alternative OCI runtime

- **What.** `youki` (Rust OCI runtime, CNCF sandbox) is roughly 2×
  faster than runc per its own benchmark. `runsc` (gVisor) is an
  in-process kernel providing VM-class isolation with container
  startup times.
- **Primary source.**
  <https://github.com/youki-dev/youki>,
  <https://gvisor.dev/docs/>.
- **Why edge.** Both drop into the existing OCI runtime slot. gVisor
  in particular is a defence-in-depth story for multi-tenant hosts
  (a kernel exploit inside the sandbox does not reach the host
  kernel) with a doc trail nix-oci does not yet write.
- **Fit.** Extend `oci.container.performance.runtime-selection.nix`
  (already exists) to list `youki`, `runsc`, `kata-runtime` and emit
  the Quadlet `Runtime=` field.
- **Effort.** Small (option); doc page for the tradeoff matrix is the
  cost.

---

## 3. Image spec evolution

### 3.1 OCI image-spec 1.1 emission (subject + artifactType)

- **What.** OCI image-spec 1.1 introduced the `subject` descriptor on
  manifests, the `artifactType` field, and the `application/vnd.oci
  .empty.v1+json` config. Distribution-spec 1.1 added
  `GET /v2/<name>/referrers/<digest>`. Together they replace tag-based
  sig/SBOM discovery with first-class referrer lookup.
- **Primary source.**
  <https://github.com/opencontainers/image-spec/blob/main/manifest.md>,
  <https://github.com/opencontainers/distribution-spec/blob/main/spec.md>,
  <https://opencontainers.org/posts/blog/2024-03-13-image-and-distribution-1-1/>.
- **Why edge.** The pipeline attaches SBOMs and signatures. Without
  `subject`, they land at tags like `sha256-<digest>.sig`, which
  every consumer must reconstruct by convention. With `subject`,
  `oras discover` and `cosign verify` walk the referrer graph
  natively.
- **Delta vs existing.** nix2container's manifest emission may or may
  not populate `subject`; the upstream README does not clarify.
  Investigation task first, then either upstream a PR or generate a
  1.1-compatible manifest post-hoc via `oras attach` in the pipeline.
- **Fit.** (a) A one-shot compliance test verifying the emitted
  manifest is a valid v1.1 manifest, (b) a pipeline step
  `provenance/referrer-attach` that uses `oras attach` to link SBOM,
  signature, and SLSA provenance as referrers with correct
  `artifactType` values.
- **Effort.** Small (compliance test), medium (upstream fix if
  needed).

### 3.2 zstd:chunked layers alongside SOCI

- **What.** zstd:chunked is a seekable, deduplicated compression
  format for OCI layers, implemented in containers/storage and
  consumed by podman 4.4+. Enables partial pulls and file-level dedup
  across layers.
- **Primary source.**
  <https://github.com/containers/composefs> (co-designed with
  composefs for content-addressed storage backing).
- **Why edge.** SOCI already covers the "lazy pull" axis. zstd:chunked
  covers a different axis: on-disk dedup and cache locality. The two
  compose (zstd:chunked layer content behind a SOCI/composefs index).
  For registries that do not run zot/SOCI, zstd:chunked still helps
  the podman pull path.
- **Fit.** Backend switch:
  `oci.backend = "nix2container" | "nix2container-turbo" | "nix2container-zstd-chunked"`.
  nix2container upstream does not emit zstd:chunked today (all layers
  are gzip); this is an upstream feature request or a repack step in
  the push app.
- **Effort.** Large. Layer repack + registry compatibility matrix.

### 3.3 nydus as alternative lazy-pull backend

- **What.** RAFS-based chunked, content-addressable image format with
  in-kernel EROFS backend, native lazy pull, and zran-based OCI
  compatibility. containerd plugin via `nydus-snapshotter`.
- **Primary source.**
  <https://github.com/containerd/nydus-snapshotter>.
- **Why edge.** SOCI is the AWS / containerd path. nydus is the
  Alibaba / Dragonfly path with broader kernel-level integration
  (EROFS instead of FUSE). For deployments running on kernels ≥ 5.16
  with EROFS built in, nydus outperforms SOCI on cold-start.
- **Fit.** Doc-only for now: add a "choosing a snapshotter" page to
  `docs/content/architecture/` covering SOCI vs nydus vs
  zstd:chunked; keep SOCI as default.
- **Effort.** Small (doc); large if we ship a nydus deploy module.

### 3.4 composefs + fs-verity image layer verification

- **What.** composefs mounts a read-only EROFS metadata image over a
  content-addressed backing store, with optional fs-verity integrity
  measurement. Bootc uses it for OS images; podman uses it as an
  optional storage driver.
- **Primary source.**
  <https://github.com/containers/composefs>.
- **Why edge.** fs-verity gives per-file cryptographic integrity
  enforced by the kernel on `read()`. If a layer file is tampered
  post-pull (rootkit swap), the read fails. This is the on-disk
  complement to sigstore verification at pull time.
- **Fit.** Deploy-side snapshotter option:
  `oci.snapshotter.storageDriver = "overlay" | "composefs"` and
  `oci.snapshotter.fsVerity = bool`. Depends on host kernel + FS
  support (ext4/btrfs with fs-verity).
- **Effort.** Medium (deploy module + kernel-support probe).

---

## 4. New scanners / policy engines not yet in the pipeline

### 4.1 OSV-Scanner as a second-source CVE scanner

- **What.** Google's scanner backed by OSV.dev's normalised advisory
  database. Layer-aware for container images. Supports 11+ lockfile
  ecosystems; OSV.dev consolidates GHSA, PyPA, RustSec, GoVulnDB,
  etc.
- **Primary source.** <https://github.com/google/osv-scanner>.
- **Why edge.** Trivy + grype both hit the same NVD backbone with
  distro-specific enrichment. OSV covers language-ecosystem
  advisories more comprehensively (Go stdlib CVEs land in OSV before
  most distro trackers pick them up). Second-source scanning catches
  the CVE-not-yet-in-NVD case.
- **Fit.** New pipeline step `oci.pipeline.steps.osvScanner` in the
  `cve` category. Same output shape as trivy/grype.
- **Effort.** Small. `osv-scanner scan image` mirrors trivy's CLI
  shape.

### 4.2 Trivy misconfig for the emitted Quadlets and NixOS units

- **What.** trivy's misconfig scanner reads Dockerfiles, IaC (Terraform,
  CloudFormation, Kubernetes YAML), and container-related config files
  for hardening antipatterns.
- **Primary source.**
  <https://github.com/aquasecurity/trivy> (Misconfig scanner).
- **Why edge.** The pipeline validates *the image*. It does not
  validate *the emitted deploy artifact* (Quadlet, NixOS
  `systemd.services.*`, home-manager unit). trivy misconfig applied
  to the generated Quadlet catches "you set `PrivateTmp=no` in the
  override" the way conftest catches "you set `USER root` in the
  image".
- **Fit.** Pipeline step `oci.pipeline.steps.deployMisconfig` in a
  new `deploy` category, running trivy misconfig against the
  generated Quadlet file. Only emitted when the deploy module is
  active.
- **Effort.** Small.

### 4.3 Kubescape image + IaC scanner

- **What.** CNCF incubating; scans Kubernetes manifests, Helm, and
  container images against NSA/CISA, MITRE ATT&CK, and CIS
  frameworks. Uses grype under the hood for image CVEs.
- **Primary source.** <https://github.com/kubescape/kubescape>.
- **Why edge.** For users who deploy the built image to Kubernetes,
  kubescape gives a *framework-mapped* report (control ID → finding)
  rather than raw findings. NSA/CISA and CIS mappings are what
  procurement audits ask for.
- **Fit.** Optional pipeline step in a `compliance` category,
  disabled by default; enable when
  `oci.pipeline.compliance.frameworks = [ "nsa" "cis" ]`.
- **Effort.** Small.

### 4.4 Trivy VM for scanning the built image without running it

- **What.** `trivy vm` scans virtual-machine disk images (VMDK, VHD,
  raw) without executing them.
- **Primary source.**
  <https://github.com/aquasecurity/trivy> (VM target).
- **Why edge.** Marginal for now. Relevant only if nix-oci ever grows
  a "build a VM image with the container baked in" path (bootc,
  microvm.nix container). Track, do not adopt yet.
- **Fit.** N/A today.
- **Effort.** N/A.

---

## 5. Runtime observability baked into the image

### 5.1 CRIU checkpoint/restore for warm-start

- **What.** `podman container checkpoint` / `restore` persist and
  resume a running container's memory + open FDs + TCP state via
  CRIU. containerd 1.7+ historically supported CRIU integration,
  though the CRI-level API is under redesign (KEP-5823 `RestorePod`).
- **Primary source.**
  <https://podman.io/docs/checkpoint>,
  <https://github.com/checkpoint-restore/criu>.
- **Why edge.** For JIT-heavy or slow-init workloads (JVM, Python
  ML), checkpointing a warmed-up process and restoring it as the
  cold-start path cuts p99 startup dramatically. Nix's determinism
  means the checkpoint image is *stable* across identical builds,
  which is the key differentiator from ad-hoc checkpointing.
- **Fit.** New pipeline step `runtime/checkpoint` (optional) that
  runs the image, warms it via a user-supplied probe, checkpoints,
  and attaches the checkpoint archive as an OCI referrer. Deploy
  side gains `oci.container.startup.mode = "cold" | "checkpoint"`.
- **Effort.** Large. Warm-up scripts and stability guarantees are
  the hard part; CRIU itself is stable.

### 5.2 OpenTelemetry zero-code auto-instrumentation opt-in

- **What.** Vendor-neutral auto-instrumentation agents for Java,
  Node.js, Python, .NET, Go, PHP that inject spans/metrics without
  application source changes.
- **Primary source.** <https://opentelemetry.io/docs/zero-code/>.
- **Why edge.** For JVM/Node images, adding
  `-javaagent:/opentelemetry-javaagent.jar` or `--require
  @opentelemetry/auto-instrumentations-node/register` at image build
  time gives free tracing at deploy. Currently users must layer this
  themselves.
- **Fit.** Per-language convenience option:
  `oci.container.observability.otel = { enable, language, endpoint }`
  that adds the agent to the closure and wires the entrypoint
  wrapper. Composes with the entrypoint hardening layer.
- **Effort.** Medium per language; small if we ship JVM only first.

---

## 6. Zero-CVE / minimalism trends

### 6.1 "Zero-CVE closure" claim as a SCAI attribute

- **What.** Chainguard's marketing hook is "images with zero known
  CVEs at build time, daily rebuild". Nix can make the equivalent
  claim more rigorously: `vulnix` over the exact closure returns
  empty at build time, and the flake input pin proves what was
  scanned.
- **Primary source.** Composition of primary sources:
  <https://github.com/nix-community/vulnix> (scanner),
  SCAI predicate above (`spec/predicates/scai.md`).
- **Why edge.** Users currently see `vulnix` output as a build log.
  Publishing "zero-CVE claim as of `<timestamp>` against NVD feed
  `<hash>`" as a signed SCAI attestation attached to the image is a
  first-party artifact procurement can consume. This is the delta
  Nix has over apko/Wolfi: our SBOM *is* the closure.
- **Delta.** vulnix already runs. SCAI predicate emission (proposal
  1.8) is the enabler. This proposal is the *policy layer* that
  turns "vulnix passed" into a signed public claim.
- **Fit.** Composes proposals 1.1 (SLSA), 1.4 (VEX), 1.8 (SCAI).
  No new options.
- **Effort.** Small once 1.8 lands.

### 6.2 apko interop: emit an apko-compatible manifest for cross-tool audit

- **What.** apko is Chainguard's declarative APK-based image builder,
  the closest philosophical peer to nix-oci. Its SBOM and manifest
  layout is a de-facto reference for "reproducible distroless".
- **Primary source.** <https://github.com/chainguard-dev/apko>.
- **Why edge.** No proposal to build with apko. Proposal: benchmark
  nix-oci's SBOM + manifest against `apko build` output on a shared
  target (e.g. nginx) as a *documentation exercise*, publish the
  matrix, and cherry-pick any missing SBOM fields.
- **Fit.** Architecture doc, no code.
- **Effort.** Small.

---

## 7. Confidential computing / TEE

### 7.1 OCI image encryption via ocicrypt (skopeo `--encryption-key`)

- **What.** Per-layer encryption with JWE, PGP, or PKCS7 keys,
  implemented in ocicrypt and driven by
  `skopeo copy --encryption-key`. Layers stay encrypted at rest in
  the registry; runtime decrypts with the recipient key.
- **Primary source.**
  <https://github.com/containers/skopeo/blob/main/docs/skopeo-copy.1.md>,
  <https://github.com/containers/ocicrypt>.
- **Why edge.** For confidential-workload registries (proprietary ML
  weights, secrets baked into a config layer against best practice
  but sometimes unavoidable), encrypted layers are the standards path
  and Confidential-Containers' expected input.
- **Fit.** New push app variant:
  `oci.container.push.encryption = { enable, protocol, keyFile,
  encryptLayers }` that swaps `skopeo copy` for its `--encryption-key`
  form.
- **Effort.** Small (option + app wrapper).

### 7.2 Confidential Containers (Kata) deploy path

- **What.** Kata Containers + Confidential Containers project provide
  a container runtime that boots the workload inside a hardware TEE
  (SEV-SNP, TDX, CCA) with attestation. Encrypted images (see 7.1)
  are the canonical input.
- **Primary source.**
  <https://github.com/kata-containers/kata-containers>,
  Veraison services for verifier side
  (<https://github.com/veraison/services>).
- **Why edge.** Gives a runtime-attested guarantee that the exact
  signed image executed inside a measured TEE. Complements SLSA
  (build-time integrity) with runtime-time integrity.
- **Fit.** Deploy-side documentation: how to configure the emitted
  Quadlet or NixOS unit to select `runtime=kata-cc`, plus a note
  about needing 7.1 for the image side. No new options in scope for
  the image builder itself.
- **Effort.** Small (doc).

---

## 8. Networking + policy

### 8.1 Tetragon TracingPolicy bundled with the image

- **What.** Cilium Tetragon is an eBPF runtime security engine
  (process, syscall, I/O). TracingPolicy is a CRD-shaped YAML that
  defines what to observe and enforce (kill, override return value)
  on named syscalls/kprobes.
- **Primary source.** <https://github.com/cilium/tetragon>.
- **Why edge.** Seccomp is coarse (allow/deny a syscall for the
  lifetime of the process). Tetragon can express "deny `execve` of
  anything not under `/nix/store` after PID 1 has fully started",
  which maps naturally to a Nix-built image where the store path is
  known at build time. Shipping the TracingPolicy YAML *alongside*
  the image as an OCI referrer means the deploy side inherits the
  hardening policy without extra config.
- **Fit.** New option
  `oci.container.hardening.tetragonPolicy = { enable, extraRules }`
  that (a) generates a TracingPolicy with defaults derived from the
  image (allowed execve paths = store closure), (b) attaches it as a
  referrer with `artifactType = "application/vnd.cilium.tetragon
  .tracingpolicy.v1+yaml"`.
- **Effort.** Medium. Policy generation from closure is the
  interesting piece.

### 8.2 Netavark firewall/policy driver awareness

- **What.** podman's rust-based network stack (default since 4.0);
  supports nftables and firewalld drivers, handles rootless NAT and
  port forwarding without CNI.
- **Primary source.** <https://github.com/containers/netavark>.
- **Why edge.** For per-container firewall rules that need to survive
  a Quadlet regenerate, netavark's driver-native declarative form is
  the target rather than post-hoc `iptables` calls. Not a huge
  security delta today; more about correctness on newer hosts.
- **Fit.** Deploy-doc addition; no new options unless the ecosystem
  exposes more policy surface.
- **Effort.** Small (doc).

---

## Prioritisation

Ordered by ratio of security/supply-chain value to implementation
effort, with cross-references to enabling proposals.

| Rank | Proposal | Effort | Category |
|---|---|---|---|
| 1 | 1.1 SLSA v1.1 provenance predicate | Medium | Supply chain |
| 2 | 1.5 Sigstore protobuf bundle output | Small | Supply chain |
| 3 | 3.1 OCI 1.1 manifest + referrer attach | S / M | Image spec |
| 4 | 4.1 OSV-Scanner second source | Small | Scanners |
| 5 | 1.4 OpenVEX authoring + attach | Medium | Supply chain |
| 6 | 1.2 GitHub Artifact Attestations | Small | Supply chain |
| 7 | 2.2 Newer systemd hardening for Quadlets | Small | Hardening |
| 8 | 2.3 CDI device injection | Small | Hardening |
| 9 | 1.8 SCAI predicate from hardening config | Medium | Supply chain |
| 10 | 6.1 Zero-CVE SCAI claim (depends on 9) | Small | Minimalism |
| 11 | 4.2 Trivy misconfig on emitted Quadlet | Small | Scanners |
| 12 | 2.1 Landlock self-restriction wrapper | Medium | Hardening |
| 13 | 1.3 GUAC ingest doc + optional push step | S / M | Supply chain |
| 14 | 2.4 pasta as rootless default | Small | Hardening |
| 15 | 8.1 Tetragon TracingPolicy as referrer | Medium | Networking |
| 16 | 2.6 youki / gVisor runtime selection | Small | Hardening |
| 17 | 7.1 ocicrypt encrypted push | Small | TEE |
| 18 | 3.4 composefs + fs-verity snapshotter | Medium | Image spec |
| 19 | 1.6 CycloneDX 1.6 crypto-assets | Small | Supply chain |
| 20 | 5.1 CRIU checkpoint/restore warm-start | Large | Observability |

Ranks 1–5 are the "next quarter" batch: they close the biggest
supply-chain and image-spec gaps and all have primary-source-defined
schemas. Ranks 15–20 are speculative and gated on ecosystem maturity
or upstream nix2container changes.
