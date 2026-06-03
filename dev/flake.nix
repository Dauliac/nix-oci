{
  description = "Development-only inputs for nix-oci (not inherited by consumers)";
  inputs = {
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
    };
  };
  outputs = _: { };
}
