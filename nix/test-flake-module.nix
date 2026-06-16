# Test infrastructure flake module.
#
# Consumers import this alongside the main nix-oci module to get:
# - BDD test collector + VM test builder
# - Container probes (amicontained, CDK, DEEPCE, linPEAS)
# - Testing tools (dive, dgoss, CST, podman sandbox)
# - Policy runner infrastructure
# - Test apps (nix run .#app-<tool>-<container>)
#
# The testing modules live in oci/_testing/ (underscore-prefixed) so they
# are excluded from the main import-tree. This module explicitly imports them.
inputs: {
  imports = [
    (inputs.import-tree ./modules/oci/_testing)
  ];
}
