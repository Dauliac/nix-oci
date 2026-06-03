@test "Run app cve with trivy" {
  run nix run '.#oci-container-structure-test-minimalistWithContainerStructureTest'
  [ "$status" -eq 0 ]
}

@test "Run app cve with grype" {
  run nix run '.#oci-cve-grype-minimalistWithGrype'
  [ "$status" -eq 0 ]
}

@test "Run app cve with trivy and ignore file" {
  run nix run '.#oci-cve-trivy-minimalistWithTrivyIgnore'
  [ "$status" -eq 0 ]
}
