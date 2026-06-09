#!/usr/bin/env bats

# Multi-arch integration tests
# Auto-discovers push-tmp, merge, and multiarch apps/packages from the flake.
# Expects NIX_OCI_APPS_JSON, NIX_OCI_PKGS_JSON, NIX_OCI_FLAKE_REF set by the Taskfile.

setup() {
  [[ -n "${NIX_OCI_APPS_JSON:-}" ]] || skip "NIX_OCI_APPS_JSON not set (run via 'task test:bats')"

  export OCI_DIR="${BATS_FILE_TMPDIR}/oci-test"
  mkdir -p "$OCI_DIR"

  local machine
  machine=$(uname -m)
  case "$machine" in
    x86_64)  CURRENT_ARCH="amd64" ;;
    aarch64) CURRENT_ARCH="arm64" ;;
    *)       CURRENT_ARCH="unknown" ;;
  esac
  export CURRENT_ARCH

  # Rebuild arrays each test (arrays don't survive bats subshells)
  PUSH_TMP_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && PUSH_TMP_APPS+=("$name")
  done < <(echo "$NIX_OCI_APPS_JSON" | jq -r --arg arch "$CURRENT_ARCH" '
    .[] | select(startswith("oci-push-tmp-") and endswith("-" + $arch))
  ')

  MERGE_APPS=()
  while IFS= read -r name; do
    [ -n "$name" ] && MERGE_APPS+=("$name")
  done < <(echo "$NIX_OCI_APPS_JSON" | jq -r '.[] | select(startswith("oci-merge-"))')

  MULTIARCH_PKGS=()
  while IFS= read -r name; do
    [ -n "$name" ] && MULTIARCH_PKGS+=("$name")
  done < <(echo "$NIX_OCI_PKGS_JSON" | jq -r '.[] | select(startswith("oci-multiarch-"))')
}

teardown_file() {
  rm -rf "${BATS_FILE_TMPDIR}/oci-test" 2>/dev/null || true
}

# ── Push temp per-arch images ────────────────────────────────────────────

@test "Discovered at least one push-tmp app" {
  [ "${#PUSH_TMP_APPS[@]}" -gt 0 ]
}

@test "Push temp images for current architecture" {
  for app in "${PUSH_TMP_APPS[@]}"; do
    echo "==> Running: nix run ${NIX_OCI_FLAKE_REF}#${app}"
    run nix run "${NIX_OCI_FLAKE_REF}#${app}"
    echo "$output"
    [ "$status" -eq 0 ]
  done
}

@test "Push temp creates valid OCI layout" {
  local app="${PUSH_TMP_APPS[0]}"
  rm -rf "$OCI_DIR"
  mkdir -p "$OCI_DIR"

  run nix run "${NIX_OCI_FLAKE_REF}#${app}"
  [ "$status" -eq 0 ]

  [ -f "${OCI_DIR}/oci-layout" ]
  [ -f "${OCI_DIR}/index.json" ]
  [ -d "${OCI_DIR}/blobs" ]
}

# ── Merge (expect failure with only one arch) ───────────────────────────

@test "Discovered at least one merge app" {
  [ "${#MERGE_APPS[@]}" -gt 0 ]
}

@test "Merge fails when missing architecture images" {
  for merge_app in "${MERGE_APPS[@]}"; do
    local container_id="${merge_app#oci-merge-}"
    local push_app="oci-push-tmp-${container_id}-${CURRENT_ARCH}"

    local found=false
    for p in "${PUSH_TMP_APPS[@]}"; do
      [ "$p" = "$push_app" ] && found=true && break
    done
    $found || continue

    rm -rf "$OCI_DIR"
    mkdir -p "$OCI_DIR"

    echo "==> Pushing single arch: nix run ${NIX_OCI_FLAKE_REF}#${push_app}"
    nix run "${NIX_OCI_FLAKE_REF}#${push_app}"

    echo "==> Merging (should fail): nix run ${NIX_OCI_FLAKE_REF}#${merge_app}"
    run nix run "${NIX_OCI_FLAKE_REF}#${merge_app}"
    echo "$output"
    [ "$status" -ne 0 ]
  done
}

# ── Cross-compiled multiarch packages ───────────────────────────────────

@test "Discovered at least one multiarch package" {
  [ "${#MULTIARCH_PKGS[@]}" -gt 0 ]
}

@test "Multiarch packages build and have valid manifests" {
  for pkg in "${MULTIARCH_PKGS[@]}"; do
    echo "==> Building: nix build ${NIX_OCI_FLAKE_REF}#${pkg}"
    run nix build "${NIX_OCI_FLAKE_REF}#${pkg}" --no-link --print-out-paths
    echo "$output"
    [ "$status" -eq 0 ]

    local layout="$output"
    local manifest
    manifest=$(skopeo inspect --raw "oci:${layout}:latest")
    local media
    media=$(echo "$manifest" | jq -r '.mediaType')
    [ "$media" = "application/vnd.oci.image.index.v1+json" ]

    local arch_count
    arch_count=$(echo "$manifest" | jq '.manifests | length')
    [ "$arch_count" -ge 2 ]

    local os_count
    os_count=$(echo "$manifest" | jq '[.manifests[].platform.os] | unique | length')
    [ "$os_count" -eq 1 ]
    local os
    os=$(echo "$manifest" | jq -r '.manifests[0].platform.os')
    [ "$os" = "linux" ]

    echo "    architectures: $(echo "$manifest" | jq -c '[.manifests[].platform.architecture] | sort')"
  done
}

@test "Multiarch per-arch manifests have valid layers" {
  for pkg in "${MULTIARCH_PKGS[@]}"; do
    run nix build "${NIX_OCI_FLAKE_REF}#${pkg}" --no-link --print-out-paths
    [ "$status" -eq 0 ]
    local layout="$output"

    for tag in $(jq -r '.manifests[] | select(.mediaType == "application/vnd.oci.image.manifest.v1+json") | .annotations["org.opencontainers.image.ref.name"]' "$layout/index.json"); do
      local arch_manifest
      arch_manifest=$(skopeo inspect --raw "oci:${layout}:${tag}")
      local media
      media=$(echo "$arch_manifest" | jq -r '.mediaType')
      [ "$media" = "application/vnd.oci.image.manifest.v1+json" ]
      local layers
      layers=$(echo "$arch_manifest" | jq '.layers | length')
      [ "$layers" -ge 1 ]
    done
  done
}
