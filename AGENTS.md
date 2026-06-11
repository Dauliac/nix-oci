# Agents Directives

## IMPORTANT: Always read CONTRIBUTING.md first

Before making any code changes, **always read `CONTRIBUTING.md`** at the project root. It documents:
- The one-file-per-option module pattern (file path = option path)
- How to add new options (auto-discovery, no registration needed)
- When NOT to split files (submodules, OCI structs, type-coupled files)
- Auto-discovery mechanisms (import-tree, discoverModules, default.nix)
- Naming conventions (kebab-case filenames)
- Architecture (flake-parts, NixOS eval bus, service adapters, no IFD)

## flake.parts-website submodule (`docs/flake-parts-website/`)

This is a fork of `https://github.com/hercules-ci/flake.parts-website`.

### Keeping the fork in sync

Always rebase onto the upstream remote before pushing:

```bash
cd docs/flake-parts-website
git remote add upstream https://github.com/hercules-ci/flake.parts-website.git  # once
git fetch upstream
git rebase upstream/main
git push origin main --force-with-lease
```

### Updating nix-oci documentation

When nix-oci options, descriptions, or examples change, update the corresponding
content in `docs/flake-parts-website/` (the nix-oci entry in the website data).

After editing:

1. Commit and push changes inside the submodule:
   ```bash
   cd docs/flake-parts-website
   git add -A && git commit -m "docs(nix-oci): <describe change>"
   git push origin main
   ```
2. Update the submodule ref in the parent repo:
   ```bash
   cd ../..
   git add docs/flake-parts-website
   git commit -m "docs(website): update flake.parts-website submodule"
   ```
3. Update the flake lock so the `docs` partition picks up the new commit:
   ```bash
   nix flake update flake-parts-website --flake ./docs
   git add docs/flake.lock
   git commit -m "docs(website): update flake.parts-website lock"
   ```

### Creating PRs to upstream

To contribute nix-oci documentation improvements back to the official
flake.parts website, create a pull request from the fork to upstream:

```bash
cd docs/flake-parts-website
gh pr create --repo hercules-ci/flake.parts-website \
  --title "docs(nix-oci): <title>" \
  --body "<description of changes>"
```
