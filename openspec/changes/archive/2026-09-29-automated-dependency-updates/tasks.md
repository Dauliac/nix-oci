# Tasks - automated-dependency-updates

## 1. Preflight: branch protection audit

- [ ] 1.1 Verify what status checks are required on `main` today. Run `gh api repos/Dauliac/nix-oci/branches/main/protection/required_status_checks 2>&1 | jq '.contexts // .checks'`. Record the current list. If empty or missing `CI / check`, automerge in later steps is unsafe - block on 1.2.
- [ ] 1.2 If 1.1 shows no required status check for `CI / check`, decide: (a) enable it now (recommended - one-time config), or (b) ship the Renovate config with `automerge: false` across the board and enable automerge in a follow-up. `blocking:human`. Record the decision in a `bd note` on the change bead.
- [ ] 1.3 Confirm the Mend Renovate app is installable on the repo. Visit `https://github.com/apps/renovate` in a browser; verify `Dauliac/nix-oci` is selectable. No install yet - we install after `renovate.json5` merges.

## 2. Add `renovate.json5`

- [ ] 2.1 Create `renovate.json5` at repo root using the shape in `design.md - D4`. Include the `$schema` field so editors get autocomplete. Verify with `test -f renovate.json5 && grep -c '$schema' renovate.json5` returns `1`.
- [ ] 2.2 Validate the config offline: `nix run nixpkgs#renovate -- --platform=local --dry-run` from repo root (or `npx --yes --package renovate -- renovate-config-validator renovate.json5` if the nix package lags). Verify exit code `0` and no `ERROR` lines in output.
- [ ] 2.3 Add rationale comments (`// why this rule exists`) above every `packageRules[]` entry. Verify with `grep -c '^\s*//' renovate.json5` is `>= number of packageRules entries`.
- [ ] 2.4 If 1.2 chose path (b), edit `renovate.json5` to set every `automerge: true` to `automerge: false` and add a top-level comment noting the follow-up. Verify with `grep -c 'automerge: true' renovate.json5` returns `0`.

## 3. Add `renovate-config-validator` workflow (Nix-authored)

- [ ] 3.1 Edit `nix/docs.nix` at the top of the `githubActions.workflows` attrset (near `nix/docs.nix:715`) to add `workflows.renovate-config-validator` per the shape in `design.md - D3`. Trigger on `pullRequest.paths = [ "renovate.json5" ".github/workflows/renovate-config-validator.yml" ]`. Verify with `nix eval .#legacyPackages.x86_64-linux.docs-github-workflows --raw` succeeds and the generated attribute exists.
- [ ] 3.2 Regenerate workflows: `nix build .#legacyPackages.x86_64-linux.docs-github-workflows && install -m 644 result/renovate-config-validator.yml .github/workflows/`. Verify with `test -f .github/workflows/renovate-config-validator.yml`.
- [ ] 3.3 Diff-check: `git diff --stat .github/workflows/` shows only the new file, no accidental changes to `ci.yml` or `deploy-docs.yml`.

## 4. Add `update-flake-lock` fallback workflow (Nix-authored)

- [ ] 4.1 Add `workflows.update-flake-lock` in `nix/docs.nix` per `design.md - D3`, scheduled `cron = "0 3 * * 0"` (Sun 03:00 UTC) plus `workflowDispatch`. Grant `permissions = { contents = "write"; pullRequests = "write"; }`. Verify with `nix eval .#legacyPackages.x86_64-linux.docs-github-workflows --raw` and `grep -q 'update-flake-lock' <output>`.
- [ ] 4.2 Regenerate + install: `nix build .#legacyPackages.x86_64-linux.docs-github-workflows && install -m 644 result/update-flake-lock.yml .github/workflows/`. Verify with `test -f .github/workflows/update-flake-lock.yml` and no other file changed.
- [ ] 4.3 Confirm the generated YAML references `DeterminateSystems/update-flake-lock@main` and not a stale action: `grep -c 'DeterminateSystems/update-flake-lock' .github/workflows/update-flake-lock.yml` returns `>= 1`.

## 5. Documentation

- [ ] 5.1 Write `docs/content/how-to/dependency-updates.md` with the sections listed in `design.md - D5` (Enable / What automerges / What doesn't / Preview locally / Fallback workflow / Turning it off). Backlink to `renovate.json5` and to `nix/docs.nix` where the workflows live. Verify with `test -f docs/content/how-to/dependency-updates.md` and `wc -l` reports `>= 40` lines.
- [ ] 5.2 Rebuild docs to confirm no MkDocs / structure errors: `nix build .#legacyPackages.x86_64-linux.docs`. Verify exit code `0`.
- [ ] 5.3 If the how-to sidebar needs a manual entry (check `docs/mkdocs.yml` or the section index), add `dependency-updates.md` in the correct alphabetical / topical position.

## 6. Land the config, then activate

- [ ] 6.1 Open the PR with `renovate.json5`, the two new `.github/workflows/*.yml`, the `nix/docs.nix` change, and the docs page. CI should pass; the new `Renovate config validator` job should NOT run yet (it only fires on PRs touching `renovate.json5` - which this one does, so it runs and must pass).
- [ ] 6.2 After merge, install the Mend Renovate app on `Dauliac/nix-oci` from `https://github.com/apps/renovate`. Verify the app opens a `Configure Renovate` onboarding PR within ~15 minutes.
- [ ] 6.3 Merge the onboarding PR. Verify subsequent bot PRs (within the next scheduled window - Sunday 03:00 UTC) match the rules: one PR per flake input, `dependencies` label, semantic-commit title (`chore(deps):` or similar).

## 7. Post-activation verification

- [ ] 7.1 On the first Sunday after activation, review the bot's PR set. Expected: at most one PR per non-nixpkgs input, plus a separate nixpkgs PR (channel-bound). If nixpkgs opens a cross-channel PR, the `allowedVersions` regex in `renovate.json5` is wrong - fix immediately.
- [ ] 7.2 Verify automerge landed at least one green patch/minor PR without human intervention. `gh pr list --state merged --author "app/renovate" --limit 5 --json number,title,mergedBy` should show `mergedBy` == the automerge actor for at least one entry.
- [ ] 7.3 Verify no duplicate GitHub Actions PRs: `gh pr list --search "actions/checkout" --state all --limit 10` shows only Renovate-authored entries; if a Dependabot entry appears, confirm `.github/dependabot.yml` doesn't exist (`test ! -f .github/dependabot.yml`).
- [ ] 7.4 Verify `update-flake-lock` fallback works: `gh workflow run update-flake-lock.yml` manually, wait for the run, confirm a PR was opened with the expected title/labels. Close the PR without merging (Renovate is the primary path; this was just a smoke test).

## 8. Wrap-up

- [ ] 8.1 Update `MEMORY.md` with a one-line entry: dependency updates automated via Renovate app (`renovate.json5`) with `update-flake-lock` fallback workflow; nixpkgs pinned to `nixos-25.11`, no automerge on nixpkgs / major bumps.
- [ ] 8.2 File follow-up beads:
  - (a) Migrate `nix-installer-action@main` and `magic-nix-cache-action@main` to pinned tags so Renovate can update them.
  - (b) Add `bdd-vm` and `bdd-apps` to required status checks on `main` once they stabilize.
  - (c) Add a `check-generated-workflows` derivation that diffs regenerated output vs. committed YAML.
  - (d) Consider full-SHA pinning of GitHub Actions for supply-chain hardening (Renovate supports it via `pinDigests`).
  Verify with `bd list --labels change:automated-dependency-updates` shows all four.
