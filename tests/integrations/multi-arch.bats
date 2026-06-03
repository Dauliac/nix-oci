#!/usr/bin/env bats

# Multi-arch integration tests
# These tests use OCI filesystem layout for testing (no registry needed)

setup_file() {
  # Create a temporary OCI directory for testing
  export OCI_DIR="${BATS_FILE_TMPDIR}/oci-test"
  mkdir -p "$OCI_DIR"
}

teardown_file() {
  # Cleanup OCI directory
  rm -rf "${BATS_FILE_TMPDIR}/oci-test" 2>/dev/null || true
}

get_current_arch() {
  local machine
  machine=$(uname -m)
  if [ "$machine" = "x86_64" ]; then
    echo "amd64"
  elif [ "$machine" = "aarch64" ]; then
    echo "arm64"
  else
    echo "unknown"
  fi
}

@test "Push temp image for current architecture" {
  local arch
  arch=$(get_current_arch)

  # Build and push the temp image to OCI dir
  run nix run ".#oci-push-tmp-minimalistWithMultiArch-${arch}"
  echo "Output: $output"
  [ "$status" -eq 0 ]

  # Verify OCI layout structure was created
  [ -f "${OCI_DIR}/oci-layout" ]
  [ -f "${OCI_DIR}/index.json" ]
  [ -d "${OCI_DIR}/blobs" ]
}

@test "Merge fails when missing architecture images" {
  local arch
  arch=$(get_current_arch)

  # Push only current arch image
  nix run ".#oci-push-tmp-minimalistWithMultiArch-${arch}"

  # Merge should fail because other arch images are missing
  run nix run '.#oci-merge-minimalistWithMultiArch'
  echo "Output: $output"
  [ "$status" -ne 0 ]
}
