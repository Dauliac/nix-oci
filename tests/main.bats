#!/usr/bin/env bats

# End-to-end tests — auto-discovers flake apps by prefix.
# Multi-arch tests live in tests/integrations/multi-arch.bats.

setup_file() {
  local machine
  machine=$(uname -m)
  local system
  case "$machine" in
    x86_64)  system="x86_64-linux" ;;
    aarch64) system="aarch64-linux" ;;
    *)       system="${machine}-linux" ;;
  esac
  export NIX_SYSTEM="$system"

  # One-shot flake introspection for the whole file
  local flake_json
  flake_json=$(nix flake show --json 2>/dev/null)

  apps_for_prefix() {
    echo "$flake_json" | jq -r --arg sys "$system" --arg pfx "$1" '
      .apps[$sys] // {} | keys[] | select(startswith($pfx))
    '
  }

  # Container-structure-test apps
  CST_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && CST_APPS+=("$name")
  done < <(apps_for_prefix "oci-container-structure-test-")
  export CST_APPS

  # CVE scanner apps
  CVE_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && CVE_APPS+=("$name")
  done < <(apps_for_prefix "oci-cve-")
  export CVE_APPS

  # Credentials leak apps
  CRED_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && CRED_APPS+=("$name")
  done < <(apps_for_prefix "oci-credentials-leak-")
  export CRED_APPS

  # SBOM apps
  SBOM_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && SBOM_APPS+=("$name")
  done < <(apps_for_prefix "oci-sbom-")
  export SBOM_APPS

  # Dgoss apps
  DGOSS_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && DGOSS_APPS+=("$name")
  done < <(apps_for_prefix "oci-dgoss-")
  export DGOSS_APPS
}

# ── Flake health ─────────────────────────────────────────────────────────

@test "Flake show works" {
  run nix flake show
  [ "$status" -eq 0 ]
}

@test "Nix can run all checks" {
  run nix flake check
  [ "$status" -eq 0 ]
}

# ── Container Structure Tests (auto-discovered) ─────────────────────────

@test "Discovered at least one CST app" {
  [ "${#CST_APPS[@]}" -gt 0 ]
}

@test "All container-structure-tests pass" {
  for app in "${CST_APPS[@]}"; do
    echo "==> Running: nix run .#${app}"
    run nix run ".#${app}"
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
    echo "==> Running: nix run .#${app}"
    run nix run ".#${app}"
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
    echo "==> Running: nix run .#${app}"
    run nix run ".#${app}"
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
    echo "==> Running: nix run .#${app}"
    run nix run ".#${app}"
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
    echo "==> Running: nix run .#${app}"
    run nix run ".#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

# ── Misc ─────────────────────────────────────────────────────────────────

@test "Update pulled manifests locks works" {
  run nix run '.#oci-updatePulledManifestsLocks'
  [ "$status" -eq 0 ]
}

@test "Nix default template works" {
  local -gx repo_dir
  repo_dir=$(git rev-parse --show-toplevel)
  local -xg working_dir
  working_dir=$(mktemp -d)
  cd "$working_dir"
  git init -b main
  run nix flake init -t "$repo_dir"
  [ "$status" -eq 0 ]
  git add .
  run nix flake show --override-input nix-oci "path:$repo_dir"
  [ "$status" -eq 0 ]
}
