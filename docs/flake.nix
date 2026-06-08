{
  description = "Documentation-only inputs for nix-oci (not inherited by consumers)";
  inputs = {
    github-actions-nix = {
      url = "github:synapdeck/github-actions-nix";
    };
  };
  outputs = _: { };
}
