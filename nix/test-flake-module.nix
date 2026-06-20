# Test infrastructure flake module.
#
# Consumers import this alongside the main nix-oci module to get:
# - BDD test collector + VM test builder
# - Container probes (amicontained, CDK, DEEPCE, linPEAS)
# - Testing tools (dive, dgoss, CST, VM check runner)
# - Policy runner infrastructure
# - Test apps (nix run .#app-<tool>-<container>)
inputs: {
  imports = [
    (inputs.import-tree ./modules/oci/testing)
  ];
}
