# Design: automated-dependency-updates

## Context

See `proposal.md - Why` for motivation. Design-relevant facts about
the current state:

- **Workflows are Nix-generated**: `nix/docs.nix:709-819` declares
  `githubActions = { enable = true; workflows.ci = { ... };
  workflows.deploy-docs = { ... }; };`. The `docs`-partition input
  `github-actions-nix` (`docs/flake.nix`) exposes
  `flakeModules.default`, imported at `flake.nix:61`. Committed YAML
  under `.github/workflows/` is a **build output** of
  `nix build .#legacyPackages.x86_64-linux.docs-github-workflows`
  (`nix/docs.nix:704`), not a source. Any new workflow MUST be
  authored as a Nix attrset there, or it will silently diverge.

- **Six flake inputs, tiered pinning**:
  1. `nixpkgs` on a channel branch (`nixos-25.11`, `flake.nix:4`).
  2. `nix2container`, `flake-parts`, `import-tree` unpinned (track
     upstream default branch).
  3. `nix2container-turbo` with `inputs.nix2container.follows =
     "nix2container"` for dedup.
  4. `nix-lib` with `inputs.nixpkgs.follows = "nixpkgs"`.
  5. `docs/` partition pulls `github-actions-nix` transitively.
  Renovate's `nix` manager updates the `rev` and `narHash` in
  `flake.lock` per input independently, which is exactly the
  granularity we want.

- **Action pins mix tag and branch**: `actions/checkout@v4`,
  `actions/upload-pages-artifact@v3`, `actions/deploy-pages@v4` are
  semver-ish major tags (Renovate can bump within `v4.x` if we
  change them to full semver, or leave them alone at the major-tag
  level). `DeterminateSystems/nix-installer-action@main` and
  `magic-nix-cache-action@main` are branch refs and inherently
  auto-update; Renovate cannot pin them without a policy change we
  are not making here.

- **Rejected alternative - Dependabot**: Dependabot's
  `package-ecosystem` list has `github-actions` and roughly two dozen
  language ecosystems, but no `nix`. It would cover a strict subset
  of Renovate's surface and produce duplicate GHA-bump PRs. Not
  worth the co-installation cost.

- **Rejected alternative - hand-rolled `update-flake-lock` only**:
  This is what most small Nix projects do (scheduled cron opens one
  monolithic PR with the whole `flake.lock`). It works but loses
  per-input bisection: if one bump breaks CI, you either merge the
  whole PR or none of it. We keep this as a **fallback workflow**
  (see proposal), not the primary mechanism.

## Goals / Non-Goals

**Goals**:

- One PR per flake input, so a broken bump can be closed without
  blocking the others.
- Auto-merge for low-risk bumps (patch/minor of pinned dependencies,
  passing all required checks).
- Zero drift between authored config and shipped config: the
  Renovate config lives in the repo and is validated on every PR
  that touches it; the workflows live in `nix/docs.nix` and are
  regenerated via the same pipeline as `ci.yml`.
- A survival path if the Mend Renovate app is uninstalled: the
  fallback `update-flake-lock` workflow continues to work standalone.

**Non-goals**:

- Cross-channel nixpkgs migration (`nixos-25.11` -> `nixos-26.05`).
  This is a coordinated decision that touches downstream module
  behavior and NixOS release semantics; bots must not drive it.
- Self-hosted Renovate. The Mend app is free for public repos and
  requires no infrastructure. Self-hosting is a fallback if we ever
  go private.
- Auto-merge for major bumps. Major = human review.
- Vendoring pinning of GitHub Actions to full SHAs (a security
  hardening move we might do later; explicitly out of scope so this
  change stays focused on update automation).

## Decisions

### D1. Renovate config format: JSON5, not JSON

`renovate.json5` allows comments. Rationale for each `packageRules`
entry needs to travel with the config; a bare `renovate.json` forces
that context into a separate doc that will rot. Renovate supports
JSON5 natively (`renovate-config-validator` accepts both).

### D2. Auto-merge scope

Auto-merge fires **only when all four are true**:

1. Update type is `patch` or `minor` (per Renovate's `updateType`).
2. All required status checks pass. Today: `CI / check`. Enforced
   by GitHub branch protection, not by Renovate config.
3. Package matches a rule with `automerge: true`. This is enabled
   per-manager (nix flake inputs, GitHub Actions tags), not
   globally.
4. `platformAutomerge: true` at the top level, so Renovate uses
   GitHub's native auto-merge (queues the merge, waits for checks,
   merges when green) instead of polling and merging itself.

Explicitly excluded from auto-merge: `nixpkgs` (any bump - even
patch within a channel gets a human look because the module system
is wide-blast-radius), `major` update type across the board, any
input flagged with `security` (routed to a `security` label for
faster attention).

### D3. Workflow authoring - Nix, not raw YAML

Both new workflows land in `nix/docs.nix` as
`githubActions.workflows.<name>` attrsets. This is a hard invariant:
adding YAML directly to `.github/workflows/` would create a file
outside the `docs-github-workflows` derivation, which then either
(a) gets clobbered on the next regeneration or (b) creates a
permanent inconsistency between authored and shipped workflows.

Concrete shape for the validator:

```nix
workflows.renovate-config-validator = {
  name = "Renovate config validator";
  on.pullRequest.paths = [ "renovate.json5" ".github/workflows/renovate-config-validator.yml" ];
  jobs.validate = {
    runsOn = "ubuntu-latest";
    steps = [
      { name = "Checkout"; uses = "actions/checkout@v4"; }
      { name = "Validate"; uses = "suzuki-shunsuke/github-action-renovate-config-validator@v1"; }
    ];
  };
};
```

Concrete shape for the fallback lock updater:

```nix
workflows.update-flake-lock = {
  name = "Update flake.lock";
  on = {
    schedule = [ { cron = "0 3 * * 0"; } ];  # Sun 03:00 UTC
    workflowDispatch = { };
  };
  permissions = { contents = "write"; pullRequests = "write"; };
  jobs.update = {
    runsOn = "ubuntu-latest";
    steps = [
      { name = "Checkout"; uses = "actions/checkout@v4"; }
      { name = "Install Nix"; uses = "DeterminateSystems/nix-installer-action@main"; }
      { name = "Update lock"; uses = "DeterminateSystems/update-flake-lock@main";
        with_ = { pr-title = "chore(deps): update flake.lock"; pr-labels = "dependencies,nix-flake"; };
      }
    ];
  };
};
```

### D4. `renovate.json5` structure (annotated)

```json5
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  extends: [
    "config:recommended",
    ":semanticCommits",
    ":semanticCommitScopeDisabled",
    "group:allNonMajor",  // groups patch/minor across managers; overridden per-manager below
  ],
  timezone: "UTC",
  schedule: [ "before 6am on sunday" ],
  platformAutomerge: true,
  labels: [ "dependencies" ],
  prConcurrentLimit: 5,
  prHourlyLimit: 2,

  // Nix flake inputs: one PR per input, patch/minor auto-merge, major manual.
  nix: { enabled: true },
  lockFileMaintenance: {
    enabled: true,
    schedule: [ "before 6am on the first day of the month" ],
  },

  packageRules: [
    // Ungroup Nix inputs so each gets its own PR.
    {
      matchManagers: [ "nix" ],
      groupName: null,
      commitMessageTopic: "flake input {{depName}}",
    },
    // nixpkgs: pin to channel, no cross-channel jumps, no auto-merge.
    {
      matchManagers: [ "nix" ],
      matchDepNames: [ "nixpkgs" ],
      allowedVersions: "/^nixos-25\\.11$/",
      automerge: false,
      labels: [ "dependencies", "nix-nixpkgs" ],
    },
    // Other Nix inputs: patch/minor auto-merge.
    {
      matchManagers: [ "nix" ],
      matchDepNames: [ "!nixpkgs" ],
      matchUpdateTypes: [ "patch", "minor" ],
      automerge: true,
    },
    // GitHub Actions with pinned tags: patch/minor auto-merge.
    {
      matchManagers: [ "github-actions" ],
      matchUpdateTypes: [ "patch", "minor" ],
      automerge: true,
    },
    // @main refs: skip (they update themselves; Renovate would churn).
    {
      matchManagers: [ "github-actions" ],
      matchCurrentValue: "main",
      enabled: false,
    },
    // Any security update: label + no auto-merge (human eyes fast, decision manual).
    {
      matchDatasources: [ "*" ],
      matchDepTypes: [ "*" ],
      vulnerabilityAlerts: { labels: [ "security" ], automerge: false },
    },
  ],
}
```

Every rule carries a one-line rationale as a JSON5 comment so future
edits know why the rule exists.

### D5. Docs surface

Add `docs/content/how-to/dependency-updates.md`. Content skeleton:

- **Enable**: install the Mend Renovate app on the repo (link to
  `https://github.com/apps/renovate`); Renovate reads
  `renovate.json5` and opens a `Configure Renovate` PR on first run.
- **What auto-merges**: table of manager x update-type x auto-merge.
- **What does not**: nixpkgs (any), major (any), security alerts.
- **Preview locally**: `nix flake update <input>` for a single input,
  `nix flake update` for the full sweep, `nix flake metadata --json |
  jq '.locks.nodes | keys'` to list managed inputs.
- **Fallback workflow**: how the `update-flake-lock` GHA behaves
  when Renovate is offline.
- **Turning it off**: uninstall the app, remove `renovate.json5`,
  set `githubActions.workflows.update-flake-lock = null;` if
  desired.

### D6. Regenerate + commit workflow files

After `nix/docs.nix` gains the two new workflow entries, run:

```
nix build .#legacyPackages.x86_64-linux.docs-github-workflows
install -m 644 result/renovate-config-validator.yml .github/workflows/
install -m 644 result/update-flake-lock.yml .github/workflows/
```

Both files must be committed alongside the Nix source (existing
convention: `ci.yml`, `deploy-docs.yml` are committed regenerated
outputs, per `nix/docs.nix:704`). CI does not verify freshness
today - a follow-up bead can add a `check-generated-workflows`
derivation that diffs on-disk vs. regenerated output.

## Risks / Trade-offs

- **Renovate app dependency**: relies on a third-party GitHub app.
  Mitigation: the fallback `update-flake-lock` workflow keeps
  the repo updateable without the app.
- **PR fatigue**: six inputs + three action tags + monthly lock
  maintenance = up to ten bot PRs/month at steady state. Mitigated
  by `prConcurrentLimit: 5` and `prHourlyLimit: 2` throttles, and by
  auto-merge draining the queue on green CI.
- **Auto-merge on a broken CI**: if branch protection isn't set to
  require `CI / check`, auto-merge could land a broken PR. Mitigated
  by tasks.md step verifying branch protection state; if unset, the
  auto-merge rules are toggled off until it is.
- **`renovate.json5` drift**: config validation catches syntax
  errors; it does not catch semantic mistakes (rule ordering,
  matcher globs). Mitigated by keeping every rule tightly scoped and
  by the rationale-comment convention.

## Migration Plan

None - greenfield. No pre-existing bot config to reconcile.

## Open Questions

- **Pin GHA to SHA?** Full-SHA pinning of actions is a security
  hardening (protects against tag-move attacks). Not adopted here;
  captured as a follow-up bead. Renovate supports it if we decide
  to.
- **`bdd-vm` / `bdd-apps` as required checks?** Currently only
  `CI / check` is a required check. Auto-merge will land bumps
  green on `CI / check` even if the BDD suite is red locally.
  Decision on adding BDD to required checks is a
  separate branch-protection change; captured as `blocking:human`.
- **`docs/` sub-flake inputs**: the `docs/` partition has its own
  `flake.lock`. Renovate's `nix` manager should pick it up
  automatically (it walks any `flake.nix` in the repo), but the
  first PR sweep may surface surprises. Verified as part of tasks
  step 4.
