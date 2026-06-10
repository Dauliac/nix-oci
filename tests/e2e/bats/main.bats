#!/usr/bin/env bats

# End-to-end tests — auto-discovers flake apps by prefix.
# Expects NIX_OCI_APPS_JSON and NIX_OCI_FLAKE_REF set by the Taskfile.

# Helper: build array from JSON for a given prefix.
# Must be called in each test (arrays don't survive across bats subshells).
_apps_for_prefix() {
  local -n _arr=$1
  local pfx=$2
  _arr=()
  while IFS= read -r name; do
    [ -n "$name" ] && _arr+=("$name")
  done < <(echo "$NIX_OCI_APPS_JSON" | jq -r --arg pfx "$pfx" '.[] | select(startswith($pfx))')
}

setup() {
  [[ -n "${NIX_OCI_APPS_JSON:-}" ]] || skip "NIX_OCI_APPS_JSON not set (run via 'task test:bats')"
}

# ── Flake health ─────────────────────────────────────────────────────────

@test "Flake show works" {
  run nix flake show "$NIX_OCI_FLAKE_REF"
  [ "$status" -eq 0 ]
}

@test "Nix can run all checks" {
  run nix flake check "$NIX_OCI_FLAKE_REF"
  [ "$status" -eq 0 ]
}

# ── Container Structure Tests (auto-discovered) ─────────────────────────

@test "Discovered at least one CST app" {
  _apps_for_prefix CST_APPS "oci-container-structure-test-"
  [ "${#CST_APPS[@]}" -gt 0 ]
}

@test "All container-structure-tests pass" {
  _apps_for_prefix CST_APPS "oci-container-structure-test-"
  for app in "${CST_APPS[@]}"; do
    echo "==> Running: nix run ${NIX_OCI_FLAKE_REF}#${app}"
    run nix run "${NIX_OCI_FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── CVE scanners (auto-discovered) ──────────────────────────────────────

@test "Discovered at least one CVE app" {
  _apps_for_prefix CVE_APPS "oci-cve-"
  [ "${#CVE_APPS[@]}" -gt 0 ]
}

@test "All CVE scans pass" {
  _apps_for_prefix CVE_APPS "oci-cve-"
  for app in "${CVE_APPS[@]}"; do
    echo "==> Running: nix run ${NIX_OCI_FLAKE_REF}#${app}"
    run nix run "${NIX_OCI_FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── Credentials leak scanners (auto-discovered) ─────────────────────────

@test "Discovered at least one credentials-leak app" {
  _apps_for_prefix CRED_APPS "oci-credentials-leak-"
  [ "${#CRED_APPS[@]}" -gt 0 ]
}

@test "All credentials leak scans pass" {
  _apps_for_prefix CRED_APPS "oci-credentials-leak-"
  for app in "${CRED_APPS[@]}"; do
    echo "==> Running: nix run ${NIX_OCI_FLAKE_REF}#${app}"
    run nix run "${NIX_OCI_FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── SBOM generators (auto-discovered) ───────────────────────────────────

@test "Discovered at least one SBOM app" {
  _apps_for_prefix SBOM_APPS "oci-sbom-"
  [ "${#SBOM_APPS[@]}" -gt 0 ]
}

@test "All SBOM generators pass" {
  _apps_for_prefix SBOM_APPS "oci-sbom-"
  for app in "${SBOM_APPS[@]}"; do
    echo "==> Running: nix run ${NIX_OCI_FLAKE_REF}#${app}"
    run nix run "${NIX_OCI_FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── Dgoss tests (auto-discovered) ───────────────────────────────────────

@test "Discovered at least one dgoss app" {
  _apps_for_prefix DGOSS_APPS "oci-dgoss-"
  [ "${#DGOSS_APPS[@]}" -gt 0 ]
}

@test "All dgoss tests pass" {
  _apps_for_prefix DGOSS_APPS "oci-dgoss-"
  for app in "${DGOSS_APPS[@]}"; do
    echo "==> Running: nix run ${NIX_OCI_FLAKE_REF}#${app}"
    run nix run "${NIX_OCI_FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── Misc ─────────────────────────────────────────────────────────────────

@test "Update pulled manifests locks works" {
  run nix run "${NIX_OCI_FLAKE_REF}#oci-updatePulledManifestsLocks"
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
