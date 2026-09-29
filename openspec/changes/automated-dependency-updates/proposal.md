# Automated dependency updates

## Why

The repo has six flake inputs (`nixpkgs`, `nix2container`, `nix2container-turbo`,
`flake-parts`, `import-tree`, `nix-lib`) plus a `docs/` sub-flake that pulls
`github-actions-nix`, and three GitHub Actions consumed pinned in
`nix/docs.nix:734-819` (`actions/checkout@v4`,
`DeterminateSystems/nix-installer-action@main`,
`DeterminateSystems/magic-nix-cache-action@main`,
`actions/upload-pages-artifact@v3`, `actions/deploy-pages@v4`). Nothing
automates their refresh today - no `.github/dependabot.yml`, no `renovate.json`,
no `update-flake-lock` workflow. The lock file drifts until a human runs
`nix flake update` by hand, and action pins silently rot until a maintainer
notices. Two consequences bite:

1. **Security patches lag**: a CVE in `nixpkgs`, `nix2container`, or an
   action stays open until someone remembers to look. On a low-frequency
   solo project this can be months.
2. **Rebase debt compounds**: infrequent bulk updates hit multi-input
   version skew, forcing whoever runs the sweep to debug several bumps
   at once. That is exactly the batch-of-nine scenario dependency bots
   are designed to prevent.

The project is already opinionated about pinning (`nixpkgs` on
`nixos-25.11`, `follows` chains for transitive dedup) and about
declarative CI (workflows live in `nix/docs.nix`, not `.github/workflows/`).
Any bot config must respect both: separate PRs per input, no reckless
channel bumps, and any workflow that runs the bot must be added through
the `githubActions.workflows.*` module - not as a hand-written YAML.

## What Changes

- **Add `renovate.json5` at repo root**, opting in to the Mend-hosted
  Renovate app (free for public repos, no self-hosted runner needed).
  Config responsibilities:
  - **Nix flake inputs** via the `nix` manager: one PR per input,
    grouped `patch` and `minor` bumps only when they share the same
    input, `major` bumps get their own PR with a `major` label and no
    auto-merge.
  - **`nixpkgs` pinning discipline**: a `packageRules` entry pins
    `nixpkgs` to the `nixos-25.11` branch. Cross-channel jumps
    (`nixos-25.11 -> nixos-26.05`) are disabled; channel migration is
    a human decision, not a bot decision.
  - **GitHub Actions**: patch/minor auto-merge for pinned tags
    (`actions/checkout@v4.1.2 -> v4.1.3`). `@main` refs
    (`nix-installer-action@main`, `magic-nix-cache-action@main`) are
    excluded - they update themselves.
  - **Auto-merge gate**: only after all required checks pass
    (`CI / check` today; `bdd-vm`, `bdd-apps` once wired) and only for
    patch/minor. Uses GitHub-native auto-merge (`platformAutomerge`),
    no third-party merge queue.
  - **Schedule**: weekly, off-hours (Sunday 03:00 UTC), so bot PRs
    don't collide with active development.
  - **Grouping**: no batching across inputs by default (each input
    gets its own PR for clean bisection); a single `lockFileMaintenance`
    entry runs a monthly bulk `nix flake update` as a safety net.

- **Add `githubActions.workflows.renovate-config-validator`** in
  `nix/docs.nix`, next to the existing `ci` and `deploy-docs`
  definitions. Triggers on PRs that touch `renovate.json5` and runs
  the official validator. No CI cost on normal PRs; catches config
  regressions before they reach the Renovate app. Generated
  `.github/workflows/renovate-config-validator.yml` lands via the
  existing `docs-github-workflows` pipeline.

- **Add `githubActions.workflows.update-flake-lock`** as a **backup
  path** for scheduled full-lock refreshes independent of the Renovate
  app. Uses `DeterminateSystems/update-flake-lock@main`. Runs weekly
  and on `workflow_dispatch`. Opens a single PR with the entire updated
  `flake.lock`; **no auto-merge** - this PR exists so channel bumps and
  input-graph shifts get a human review path even if the Renovate app
  is uninstalled. If the Mend app is active, this workflow overlaps
  with `lockFileMaintenance` and can be disabled by setting
  `githubActions.workflows.update-flake-lock = null;`; kept enabled by
  default because a self-contained workflow survives loss of the
  Renovate app.

- **Enable branch protection docs**, not the setting itself: add a
  short section to `docs/content/how-to/` (new file
  `dependency-updates.md`) explaining (a) how to install the Mend
  Renovate GitHub app on a fork, (b) which PRs auto-merge and which
  don't, (c) how to run `nix flake update` locally to preview a bump.
  No new option is added; this is repo hygiene doc.

- **Do NOT add Dependabot**. Dependabot has no Nix flake manager and
  would only cover GitHub Actions - a subset Renovate already handles.
  Running both means duplicate PRs on every action bump.

## Impact

- **Affected specs**: `dependency-updates` (new capability). See
  `specs/dependency-updates/spec.md` delta - single `## ADDED
  Requirements` block covering per-input PR granularity, auto-merge
  gate, and the config-validator workflow.
- **Affected code**:
  - `renovate.json5` (new, root).
  - `nix/docs.nix` - two new `githubActions.workflows.*` entries
    (`renovate-config-validator`, `update-flake-lock`). Zero change to
    existing `ci` / `deploy-docs` definitions.
  - `docs/content/how-to/dependency-updates.md` (new).
- **Affected CI**: two new generated workflow files under
  `.github/workflows/` after the next `nix build .#legacyPackages.x86_64-linux.docs-github-workflows`
  and commit. No change to the existing `ci.yml` / `deploy-docs.yml`.
- **Affected inputs**: none added. Renovate itself is a hosted GitHub
  app (no repo-side install); the fallback workflow uses
  `DeterminateSystems/update-flake-lock@main`, an action - not a flake
  input.
- **Follow-ups (out of scope)**:
  - Wire `bdd-vm` / `bdd-apps` as required status checks once they
    stabilize on `ubuntu-latest` (currently only unit tests + `nix
    flake check` are required). Renovate auto-merge respects whatever
    the branch-protection rule requires, so this happens automatically
    when the protection rule updates.
  - Consider a `renovate.json5` `hostRules` entry for Cachix / attic
    caches once they land - not relevant today.
  - Decision on migrating from `magic-nix-cache-action@main` /
    `nix-installer-action@main` to pinned tags (so Renovate can update
    them) is captured as `blocking:human` in tasks.
