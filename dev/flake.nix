{
  description = "Development-only inputs for nix-oci (not inherited by consumers)";
  inputs = {
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
    };
  };
  outputs = _: { };
}
