{
  description = "Development-only inputs for nix-oci (not inherited by consumers)";
  inputs = {
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
    };
    nix-vm-test = {
      url = "github:numtide/nix-vm-test";
    };
    system-manager = {
      url = "github:numtide/system-manager";
    };
  };
  outputs = _: { };
}
