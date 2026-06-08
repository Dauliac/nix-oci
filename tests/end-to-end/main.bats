@test "Flake show works" {
  run nix flake show
  [ "$status" -eq 0 ]
}

@test "Nix can run all check" {
  run nix flake check
  [ "$status" -eq 0 ]
}

# BUG check why bats broke container-structure-test
# @test "Nix run container-structure-test minimalistWithContainerStructureTest" {
#   env
#   run nix run '.#oci-container-structure-test-minimalistWithContainerStructureTest'
#   [ "$status" -eq 0 ]
# }

@test "Nix run cve grype minimalistWithGrype" {
  run nix run '.#oci-cve-grype-minimalistWithGrype'
  [ "$status" -eq 0 ]
}

@test "Nix run cve trivy minimalistWithTrivyIgnore" {
  run nix run '.#oci-cve-trivy-minimalistWithTrivyIgnore'
  [ "$status" -eq 0 ]
}

@test "Update pulled manifests locks works" {
  run nix run '.#oci-updatePulledManifestsLocks'
  [ "$status" -eq 0 ]
}

@test "Nix run sbom syft" {
  run nix run '.#oci-sbom-syft-minimalistWithSyft'
  [ "$status" -eq 0 ]
}

@test "Nix run credentials leaks trivy" {
  run nix run '.#oci-credentials-leak-minimalistWithCredentialsLeaksTrivy'
  [ "$status" -eq 0 ]
}

@test "CST minimalist" {
  run nix run '.#oci-container-structure-test-minimalist'
  [ "$status" -eq 0 ]
}

@test "CST minimalistWithDependencies" {
  run nix run '.#oci-container-structure-test-minimalistWithDependencies'
  [ "$status" -eq 0 ]
}

@test "CST withRootUserAndPackage" {
  run nix run '.#oci-container-structure-test-withRootUserAndPackage'
  [ "$status" -eq 0 ]
}

@test "CST write-shell-application" {
  run nix run '.#oci-container-structure-test-write-shell-application'
  [ "$status" -eq 0 ]
}

@test "CST write-shell-script-bin" {
  run nix run '.#oci-container-structure-test-write-shell-script-bin'
  [ "$status" -eq 0 ]
}

@test "CST minimalistWithName" {
  run nix run '.#oci-container-structure-test-minimalistWithName'
  [ "$status" -eq 0 ]
}

@test "CST crossBuildCurl" {
  run nix run '.#oci-container-structure-test-crossBuildCurl'
  [ "$status" -eq 0 ]
}

@test "CST nixosNginxCst" {
  run nix run '.#oci-container-structure-test-nixosNginxCst'
  [ "$status" -eq 0 ]
}

@test "CST nixosNginxDeps" {
  run nix run '.#oci-container-structure-test-nixosNginxDeps'
  [ "$status" -eq 0 ]
}

@test "CST nixosNginxNonroot" {
  run nix run '.#oci-container-structure-test-nixosNginxNonroot'
  [ "$status" -eq 0 ]
}

@test "CST nixosNginxSyspackages" {
  run nix run '.#oci-container-structure-test-nixosNginxSyspackages'
  [ "$status" -eq 0 ]
}

@test "CST nixosCaddyCst" {
  run nix run '.#oci-container-structure-test-nixosCaddyCst'
  [ "$status" -eq 0 ]
}

@test "CST nixosDnsmasqCst" {
  run nix run '.#oci-container-structure-test-nixosDnsmasqCst'
  [ "$status" -eq 0 ]
}

@test "CST nixosRedisCst" {
  run nix run '.#oci-container-structure-test-nixosRedisCst'
  [ "$status" -eq 0 ]
}

# ── Multi-arch manifest checks ──
# Build cross-compiled multi-arch OCI layouts and verify manifests with skopeo + jq.

@test "Multi-arch crossBuild has amd64+arm64 manifest" {
  run nix build '.#oci-multiarch-crossBuild' --no-link --print-out-paths
  [ "$status" -eq 0 ]
  layout="$output"
  manifest=$(skopeo inspect --raw "oci:$layout:latest")
  arches=$(echo "$manifest" | jq -c '[.manifests[].platform.architecture] | sort')
  [ "$arches" = '["amd64","arm64"]' ]
  media=$(echo "$manifest" | jq -r '.mediaType')
  [ "$media" = "application/vnd.oci.image.index.v1+json" ]
  os_count=$(echo "$manifest" | jq '[.manifests[].platform.os] | unique | length')
  [ "$os_count" = "1" ]
  os=$(echo "$manifest" | jq -r '.manifests[0].platform.os')
  [ "$os" = "linux" ]
}

@test "Multi-arch crossBuildCurl has amd64+arm64 manifest" {
  run nix build '.#oci-multiarch-crossBuildCurl' --no-link --print-out-paths
  [ "$status" -eq 0 ]
  layout="$output"
  manifest=$(skopeo inspect --raw "oci:$layout:latest")
  arches=$(echo "$manifest" | jq -c '[.manifests[].platform.architecture] | sort')
  [ "$arches" = '["amd64","arm64"]' ]
  media=$(echo "$manifest" | jq -r '.mediaType')
  [ "$media" = "application/vnd.oci.image.index.v1+json" ]
}

@test "Multi-arch crossBuildNonRoot has amd64+arm64 manifest" {
  run nix build '.#oci-multiarch-crossBuildNonRoot' --no-link --print-out-paths
  [ "$status" -eq 0 ]
  layout="$output"
  manifest=$(skopeo inspect --raw "oci:$layout:latest")
  arches=$(echo "$manifest" | jq -c '[.manifests[].platform.architecture] | sort')
  [ "$arches" = '["amd64","arm64"]' ]
}

@test "Multi-arch crossBuildWithDeps has amd64+arm64 manifest" {
  run nix build '.#oci-multiarch-crossBuildWithDeps' --no-link --print-out-paths
  [ "$status" -eq 0 ]
  layout="$output"
  manifest=$(skopeo inspect --raw "oci:$layout:latest")
  arches=$(echo "$manifest" | jq -c '[.manifests[].platform.architecture] | sort')
  [ "$arches" = '["amd64","arm64"]' ]
}

@test "Multi-arch singleExtraArch has amd64+arm64 manifest" {
  run nix build '.#oci-multiarch-singleExtraArch' --no-link --print-out-paths
  [ "$status" -eq 0 ]
  layout="$output"
  manifest=$(skopeo inspect --raw "oci:$layout:latest")
  arches=$(echo "$manifest" | jq -c '[.manifests[].platform.architecture] | sort')
  [ "$arches" = '["amd64","arm64"]' ]
}

@test "Multi-arch per-arch manifests are valid image manifests" {
  run nix build '.#oci-multiarch-crossBuild' --no-link --print-out-paths
  [ "$status" -eq 0 ]
  layout="$output"
  # Check each per-arch entry in index.json is a valid image manifest
  for tag in $(jq -r '.manifests[] | select(.mediaType == "application/vnd.oci.image.manifest.v1+json") | .annotations["org.opencontainers.image.ref.name"]' "$layout/index.json"); do
    arch_manifest=$(skopeo inspect --raw "oci:$layout:$tag")
    media=$(echo "$arch_manifest" | jq -r '.mediaType')
    [ "$media" = "application/vnd.oci.image.manifest.v1+json" ]
    layers=$(echo "$arch_manifest" | jq '.layers | length')
    [ "$layers" -ge 1 ]
  done
}

@test "CST devShell (home-manager + zsh + starship + neovim)" {
  run nix run '.#oci-container-structure-test-devShell'
  [ "$status" -eq 0 ]
}

@test "CST nixosPostgres" {
  run nix run '.#oci-container-structure-test-nixosPostgres'
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
