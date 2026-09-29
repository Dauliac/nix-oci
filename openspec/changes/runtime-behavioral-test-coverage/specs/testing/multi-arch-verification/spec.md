## Purpose

Opt-in coverage for the multi-arch build paths (native-parallel, cross-compile, emulated) and the manifest-list merge step. Kept out of the default `nix flake check` because a single-runner CI can't build native artifacts for other architectures without additional infrastructure (remote builders, binfmt/qemu).

## ADDED Requirements

### Requirement: Multi-arch manifest merge

The test suite SHALL verify that per-arch pushes plus `mkMergeMultiArchApp` produce a valid multi-platform OCI manifest list.

#### Scenario: Two-arch merge yields an index with two manifests
- **WHEN** the multi-arch merge app runs against two synthetic per-arch tags (for example `test:x86_64-linux-abc123`, `test:aarch64-linux-abc123`) pushed to the in-VM registry
- **THEN** the resulting index tag contains a media type of `application/vnd.oci.image.index.v1+json` and the `manifests[]` array lists both architectures with their expected `platform.architecture` values

#### Scenario: Merge cleans up temp tags
- **WHEN** the merge app is invoked with the documented cleanup behavior
- **THEN** the per-arch temp tags are absent from the registry after the merge

### Requirement: Cross-compile build path

The test suite SHALL verify that a container declared for a foreign architecture builds via `pkgsCross` and produces an image whose manifest reports the foreign architecture.

#### Scenario: aarch64 image from x86_64 host
- **WHEN** the test job (opt-in) builds a small container with `multiArch.enabled = true` and `multiArch.crossBuild.enable = true` for `aarch64-linux` on an `x86_64-linux` host
- **THEN** the resulting OCI manifest reports `architecture = "arm64"`

### Requirement: Emulated build path

The test suite SHALL verify that when the flake declares multiple systems, the emulated build path produces per-arch outputs.

#### Scenario: Multi-system flake produces per-arch outputs
- **WHEN** the test job (opt-in) evaluates the flake with `systems = ["x86_64-linux" "aarch64-linux"]` and builds a small container for both
- **THEN** both outputs exist and each reports its own architecture in its manifest

### Requirement: Multi-arch tests are opt-in in CI

The test suite SHALL NOT run multi-arch verification in the default `nix flake check`.

#### Scenario: Default CI doesn't build multi-arch
- **WHEN** `ci.yml` runs on push or PR
- **THEN** the multi-arch check isn't exercised (no build attempts against foreign architectures)

#### Scenario: Workflow-dispatch trigger runs multi-arch
- **WHEN** the workflow is triggered manually with a `multi-arch: true` input (or an equivalent named job)
- **THEN** the multi-arch check job runs and its result gates the workflow outcome
