# Automate dependency updates

`nix-oci` uses [Renovate](https://docs.renovatebot.com/) to keep its
flake inputs and GitHub Actions pinned to fresh upstream versions.
Renovate opens one pull request per input on a weekly schedule and
auto-merges low-risk bumps once CI is green. A fallback GitHub Actions
workflow keeps the repo updateable if the Renovate app is ever removed.

This page explains how the automation is wired and how to change it.

## Enable Renovate on a fork

1. Install the community-hosted [Renovate app](https://github.com/apps/renovate)
   on your fork.
2. On first run Renovate opens a `Configure Renovate` onboarding PR.
   Merge it - the config lives in [`renovate.json5`](https://github.com/Dauliac/nix-oci/blob/main/renovate.json5)
   at the repo root and does not need editing during onboarding.
3. Renovate will run at the next scheduled window (Sunday, before
   06:00 UTC) or immediately after the onboarding PR merges.

The hosted app is free for public repositories. No self-hosted runner
is required.

## What auto-merges, what does not

| Manager           | Update type    | Auto-merge | Notes                                     |
| ----------------- | -------------- | ---------- | ----------------------------------------- |
| Nix flake inputs  | patch, minor   | Yes        | Everything except `nixpkgs`.              |
| Nix flake inputs  | major          | No         | Manual review; may cross API boundaries.  |
| `nixpkgs`         | any            | No         | Pinned to `nixos-25.11`; human review.    |
| GitHub Actions    | patch, minor   | Yes        | Pinned tags only (e.g. `@v4.1.2`).        |
| GitHub Actions    | major          | No         | Manual review.                            |
| GitHub Actions    | `@main` refs   | Skipped    | Refs like `nix-installer-action@main`.    |
| Security alerts   | any            | No         | Labeled `security`; human triage.         |

Auto-merge only fires when all
[branch-protection required status checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
pass. On this repo that is currently `CI / check` (unit tests +
`nix flake check`). If `bdd-vm` / `bdd-apps` are added to required
checks later, auto-merge will wait for them too - no config change
needed.

## Preview a bump locally

Before merging a bot PR you can reproduce the update yourself:

```bash
# Refresh a single input
nix flake update flake-parts

# Refresh every input
nix flake update

# List every input the lock file knows about
nix flake metadata --json | jq '.locks.nodes | keys'
```

## Fallback workflow

`.github/workflows/update-flake-lock.yml` runs weekly (Sundays,
03:00 UTC) and on manual dispatch. It opens a single PR with the full
updated `flake.lock`. It is **not auto-merged** - review each input
change before merging.

Trigger it manually:

```bash
gh workflow run update-flake-lock.yml
```

This workflow exists so the repo stays updateable if the Renovate app
is uninstalled. When Renovate is active it overlaps with the monthly
`lockFileMaintenance` sweep; the overlap is intentional and cheap
(only one PR opens per week even if both fire).

## Turning it off

- **Disable Renovate**: uninstall the app from the repo settings, or
  add `"enabled": false` at the top of `renovate.json5`.
- **Disable the fallback workflow**: set
  `githubActions.workflows.update-flake-lock = null;` in
  [`nix/docs.nix`](https://github.com/Dauliac/nix-oci/blob/main/nix/docs.nix)
  and regenerate:
  ```bash
  nix build .#legacyPackages.x86_64-linux.docs-github-workflows
  cp result/*.yml .github/workflows/
  ```
- **Adjust the schedule**: change the `schedule` array in
  `renovate.json5` (Renovate) or the `cron` field on
  `workflows.update-flake-lock` in `nix/docs.nix` (fallback).

## Related files

- `renovate.json5` - Renovate rules, per-manager auto-merge policy.
- `nix/docs.nix` - `githubActions.workflows.renovate-config-validator`
  and `workflows.update-flake-lock` definitions.
- `.github/workflows/renovate-config-validator.yml` - generated
  validator (runs on PRs touching `renovate.json5`).
- `.github/workflows/update-flake-lock.yml` - generated fallback.
