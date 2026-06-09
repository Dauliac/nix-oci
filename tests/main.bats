#!/usr/bin/env bats

# End-to-end tests — auto-discovers flake apps by prefix.
# Expects NIX_OCI_APPS_JSON and NIX_OCI_FLAKE_REF set by the Taskfile.

setup_file() {
  [[ -n "${NIX_OCI_APPS_JSON:-}" ]] || skip "NIX_OCI_APPS_JSON not set (run via 'task test:bats')"
  export FLAKE_REF="${NIX_OCI_FLAKE_REF}"

  apps_for_prefix() {
    echo "$NIX_OCI_APPS_JSON" | jq -r --arg pfx "$1" '.[] | select(startswith($pfx))'
  }

  CST_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && CST_APPS+=("$name")
  done < <(apps_for_prefix "oci-container-structure-test-")
  export CST_APPS

  CVE_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && CVE_APPS+=("$name")
  done < <(apps_for_prefix "oci-cve-")
  export CVE_APPS

  CRED_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && CRED_APPS+=("$name")
  done < <(apps_for_prefix "oci-credentials-leak-")
  export CRED_APPS

  SBOM_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && SBOM_APPS+=("$name")
  done < <(apps_for_prefix "oci-sbom-")
  export SBOM_APPS

  DGOSS_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && DGOSS_APPS+=("$name")
  done < <(apps_for_prefix "oci-dgoss-")
  export DGOSS_APPS
}

# ── Flake health ─────────────────────────────────────────────────────────

@test "Flake show works" {
  run nix flake show "$FLAKE_REF"
  [ "$status" -eq 0 ]
}

@test "Nix can run all checks" {
  run nix flake check "$FLAKE_REF"
  [ "$status" -eq 0 ]
}

# ── Container Structure Tests (auto-discovered) ─────────────────────────

@test "Discovered at least one CST app" {
  [ "${#CST_APPS[@]}" -gt 0 ]
}

@test "All container-structure-tests pass" {
  for app in "${CST_APPS[@]}"; do
    echo "==> Running: nix run ${FLAKE_REF}#${app}"
    run nix run "${FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── CVE scanners (auto-discovered) ──────────────────────────────────────

@test "Discovered at least one CVE app" {
  [ "${#CVE_APPS[@]}" -gt 0 ]
}

@test "All CVE scans pass" {
  for app in "${CVE_APPS[@]}"; do
    echo "==> Running: nix run ${FLAKE_REF}#${app}"
    run nix run "${FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── Credentials leak scanners (auto-discovered) ─────────────────────────

@test "Discovered at least one credentials-leak app" {
  [ "${#CRED_APPS[@]}" -gt 0 ]
}

@test "All credentials leak scans pass" {
  for app in "${CRED_APPS[@]}"; do
    echo "==> Running: nix run ${FLAKE_REF}#${app}"
    run nix run "${FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── SBOM generators (auto-discovered) ───────────────────────────────────

@test "Discovered at least one SBOM app" {
  [ "${#SBOM_APPS[@]}" -gt 0 ]
}

@test "All SBOM generators pass" {
  for app in "${SBOM_APPS[@]}"; do
    echo "==> Running: nix run ${FLAKE_REF}#${app}"
    run nix run "${FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── Dgoss tests (auto-discovered) ───────────────────────────────────────

@test "Discovered at least one dgoss app" {
  [ "${#DGOSS_APPS[@]}" -gt 0 ]
}

@test "All dgoss tests pass" {
  for app in "${DGOSS_APPS[@]}"; do
    echo "==> Running: nix run ${FLAKE_REF}#${app}"
    run nix run "${FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── Misc ─────────────────────────────────────────────────────────────────

@test "Update pulled manifests locks works" {
  run nix run "${FLAKE_REF}#oci-updatePulledManifestsLocks"
  [ "$status" -eq 0 ]
}

@test "Nix default template works" {
  local repo_dir
  repo_dir=$(git rev-parse --show-toplevel)
  local working_dir
  working_dir=$(mktemp -d)
  cd "$working_dir"
  git init -b main
  run nix flake init -t "$repo_dir"
  [ "$status" -eq 0 ]
  git add .
  run nix flake show --override-input nix-oci "path:$repo_dir"
  [ "$status" -eq 0 ]
}
