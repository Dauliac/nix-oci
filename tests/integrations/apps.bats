#!/usr/bin/env bats

# Integration tests for all runnable flake apps (auto-discovered).
# Discovers every oci-* app and runs it, grouped by prefix.

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

  local flake_json
  flake_json=$(nix flake show --json 2>/dev/null)

  # All apps except push/merge/push-tmp (those need registries or OCI_DIR)
  RUNNABLE_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && RUNNABLE_APPS+=("$name")
  done < <(echo "$flake_json" | jq -r --arg sys "$system" '
    .apps[$sys] // {} | keys[]
    | select(
        startswith("oci-container-structure-test-") or
        startswith("oci-cve-") or
        startswith("oci-credentials-leak-") or
        startswith("oci-sbom-") or
        startswith("oci-dgoss-")
      )
  ')
  export RUNNABLE_APPS
}

@test "Discovered at least one runnable app" {
  [ "${#RUNNABLE_APPS[@]}" -gt 0 ]
}

@test "All runnable apps succeed" {
  for app in "${RUNNABLE_APPS[@]}"; do
    echo "==> Running: nix run .#${app}"
    run nix run ".#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}
