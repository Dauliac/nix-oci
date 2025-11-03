@test "Flake show works" {
  cd self
  run nix flake show
  [ "$status" -eq 0 ]
}

@test "Nix can run all check" {
  cd self
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
  cd self
  run nix run '.#oci-cve-grype-minimalistWithGrype'
  [ "$status" -eq 0 ]
}

@test "Nix run cve trivy minimalistWithTrivyIgnore" {
  cd self
  run nix run '.#oci-cve-trivy-minimalistWithTrivyIgnore'
  [ "$status" -eq 0 ]
}

@test "Update pulled manifests locks works" {
  cd self
  run nix run '.#oci-updatePulledManifestsLocks'
  [ "$status" -eq 0 ]
}

@test "Nix run sbom syft" {
  cd self
  run nix run '.#oci-sbom-syft-minimalistWithSyft'
  [ "$status" -eq 0 ]
}

@test "Nix run credentials leaks trivy" {
  cd self
  run nix run '.#oci-credentials-leak-minimalistWithCredentialsLeaksTrivy'
  [ "$status" -eq 0 ]
}

@test "Nix default template works" {
  local -gx repo_dir
  repo_dir=$(git rev-parse --show-toplevel)
  local -xg working_dir
  working_dir=$(mktemp -d)
  cd "$working_dir"
  git init
  run nix flake init -t "$repo_dir"
  [ "$status" -eq 0 ]
  run nix flake show --override-input nix-oci "path:$repo_dir"
  [ "$status" -eq 0 ]
}
