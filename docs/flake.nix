{
  description = "Documentation-only inputs for nix-oci (not inherited by consumers)";
  inputs = {
    github-actions-nix = {
      url = "github:synapdeck/github-actions-nix";
    };
    ndg = {
      url = "github:feel-co/ndg";
    };
    flake-parts-website = {
      url = "github:Dauliac/flake.parts-website";
      inputs.nix-oci.follows = "/";
    };
  };
  outputs = _: { };
}
