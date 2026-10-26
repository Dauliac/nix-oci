## 1. Workflow

- [ ] 1.1 Add `.github/workflows/attest-images.yml` (or extend an existing publish workflow) with `permissions: id-token: write, attestations: write, contents: read` and a step invoking `actions/attest-build-provenance@v3` with `subject-digest` derived from the `NIX_OCI_PUSHED_DIGEST` marker and `push-to-registry: true`; verify workflow runs on a test PR and produces an attestation retrievable via `gh attestation list`

## 2. Digest marker plumbing

- [ ] 2.1 Ensure the CI job step captures `NIX_OCI_PUSHED_DIGEST` from the push step's stdout into a workflow output; verify by inspecting the workflow run summary
- [ ] 2.2 If `oci-attach-referrer-substrate` has not landed yet, add a stopgap `NIX_OCI_PUSHED_DIGEST` emitter in the push app; verify grep matches

## 3. Option surface

- [ ] 3.1 Add per-container option file `nix/modules/oci/_oci/signing/attestations/github-enabled.nix` (bool, default false, documentary only); verify option accessible via `nix eval`

## 4. Validation

- [ ] 4.1 Add a pure Nix check `.#checks.<system>.github-attest-workflow` that asserts the workflow file has the required permissions block and `attest-build-provenance` step; verify by tampering the workflow and confirming the check fails

## 5. Documentation

- [ ] 5.1 Write `docs/content/how-to/github-attestations.md` covering CI setup, required permissions, and `gh attestation verify --repo <owner>/<repo> oci://<image-ref>` on the consumer side; verify by rendering the docs site locally
