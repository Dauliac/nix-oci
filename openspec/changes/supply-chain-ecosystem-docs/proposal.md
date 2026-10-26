## Why

Four proposals in the exploration report are pure documentation exercises with no code change: GUAC (Graph for Understanding Artifact Composition) ingest walkthrough, nydus vs SOCI vs zstd:chunked snapshotter comparison, apko (Chainguard) parity comparison, and Netavark firewall-driver awareness. Bundling them as one docs-only change avoids proliferating tiny scaffolding for pieces that share a natural home under `docs/content/`. Additionally the exploration and evaluation surfaced one MEMORY.md drift ("`cosign attest` with SBOM predicate is available" is not actually wired) worth fixing in the same pass.

## What Changes

- New doc `docs/content/architecture/snapshotter-choice.md`: comparison matrix (SOCI vs stargz vs zstd:chunked vs nydus) covering compat, kernel requirements, registry support, cold-start numbers. Cross-links to existing `_snapshotter/*` option docs.
- New doc `docs/content/how-to/guac-ingest.md`: walkthrough for `guacone collect files ./oci-outputs/` against pipeline outputs (SBOM + attestation blobs). Notes `guac` not currently packaged in nixpkgs pin; overlay recipe included.
- New doc `docs/content/reference/apko-comparison.md`: benchmark matrix (`nginx` container built by nix-oci vs `apko build`) covering SBOM field coverage, manifest layout, closure size, CVE posture. `apko 0.29+` already in nixpkgs pin.
- New doc `docs/content/reference/netavark-firewall.md`: awareness note on podman's Rust network stack default since 4.0, nftables vs firewalld drivers, per-container firewall considerations. No new options.
- Correct the drift line in `/home/juliendauliac/.claude/projects/-home-juliendauliac-ghq-github-com-Dauliac-nix-oci/memory/MEMORY.md`: remove "`cosign attest` with SBOM predicate is available via the signing + SBOM steps" (it is not wired) and replace with a reference to `cosign-attest-in-toto-wrapper` as the future landing site.
- Cross-link the four new docs from `docs/content/architecture/index.md` and `docs/content/security/index.md` as appropriate.

## Capabilities

None. This change is docs + a small memory-file correction. `.openspec.yaml` will declare `skip_specs: true`.

## Impact

- No code change.
- No new nixpkgs dependency (apko already pinned; guac not pinned but overlay recipe is a doc, not a wiring).
- Corrects a false claim in project memory that could mislead future planning.
- Complements every supply-chain change in the roadmap by giving readers an ecosystem map.
