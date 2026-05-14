{
  description = "Development-only inputs for nix-oci (not inherited by consumers)";
  inputs = {
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
    };
    import-tree.url = "github:vic/import-tree";
  };
  outputs = _: { };
}
