## 1. Snapshotter comparison doc

- [ ] 1.1 Write `docs/content/architecture/snapshotter-choice.md` with a matrix comparing SOCI, stargz, zstd:chunked, and nydus across compat, kernel requirements, registry support, and cold-start numbers; verify by rendering the docs site locally
- [ ] 1.2 Cross-link from existing `nix/modules/deploy/nix-oci/options/_snapshotter/soci/*.nix` option docs and from `docs/content/architecture/index.md`; verify links resolve

## 2. GUAC ingest doc

- [ ] 2.1 Write `docs/content/how-to/guac-ingest.md` covering `guacone collect files ./oci-outputs/` against pipeline outputs (SBOM + attestation blobs); verify by rendering the docs site locally
- [ ] 2.2 Include an overlay recipe for `pkgs.guac` (fetchurl of release binary) since guac is not currently in the pinned nixpkgs; verify the overlay evaluates in a scratch flake

## 3. apko comparison doc

- [ ] 3.1 Write `docs/content/reference/apko-comparison.md` with a matrix benchmarking nix-oci vs `apko build` on a shared target (nginx), covering SBOM field coverage, manifest layout, closure size, CVE posture; verify by rendering the docs site locally
- [ ] 3.2 Run the actual benchmark: build nginx both ways, collect the diff, embed the results in the doc; verify the numbers by re-running the benchmark script

## 4. Netavark awareness doc

- [ ] 4.1 Write `docs/content/reference/netavark-firewall.md` with an awareness note on podman's Rust network stack default since 4.0, nftables vs firewalld drivers, per-container firewall considerations; verify by rendering the docs site locally
- [ ] 4.2 Cross-link from `docs/content/how-to/nixos-containers.md`; verify link resolves

## 5. MEMORY.md drift correction

- [ ] 5.1 Remove the incorrect claim "`cosign attest` with SBOM predicate is available via the signing + SBOM steps" from `/home/juliendauliac/.claude/projects/-home-juliendauliac-ghq-github-com-Dauliac-nix-oci/memory/MEMORY.md`; verify by grepping the file
- [ ] 5.2 Replace with a forward-reference to `cosign-attest-in-toto-wrapper` as the future landing site; verify replacement text present

## 6. Cross-links

- [ ] 6.1 Update `docs/content/architecture/index.md` and `docs/content/security/index.md` to list the four new pages; verify by rendering the docs site locally and clicking each new link
