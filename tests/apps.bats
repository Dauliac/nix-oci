#!/usr/bin/env bats

# Integration tests for all runnable flake apps (auto-discovered).
# Expects NIX_OCI_APPS_JSON and NIX_OCI_FLAKE_REF set by the Taskfile.

setup() {
  [[ -n "${NIX_OCI_APPS_JSON:-}" ]] || skip "NIX_OCI_APPS_JSON not set (run via 'task test:bats')"

  # Build array from JSON each test (arrays don't survive across bats subshells)
  RUNNABLE_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && RUNNABLE_APPS+=("$name")
  done < <(echo "$NIX_OCI_APPS_JSON" | jq -r '
    .[] | select(
        startswith("oci-container-structure-test-") or
        startswith("oci-cve-") or
        startswith("oci-credentials-leak-") or
        startswith("oci-sbom-") or
        startswith("oci-dgoss-") or
        startswith("oci-compliance-") or
        startswith("oci-lint-")
      )
  ')
}

@test "Discovered at least one runnable app" {
  [ "${#RUNNABLE_APPS[@]}" -gt 0 ]
}

@test "All runnable apps succeed" {
  for app in "${RUNNABLE_APPS[@]}"; do
    echo "==> Running: nix run ${NIX_OCI_FLAKE_REF}#${app}"
    run nix run "${NIX_OCI_FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}
