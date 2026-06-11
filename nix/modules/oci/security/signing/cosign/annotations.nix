{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.oci.signing.cosign.annotations = mkOption {
    type = types.attrsOf types.str;
    description = ''
      Key-value annotations to attach to every cosign signature.
      These appear in `cosign verify` output and can be used
      for policy enforcement (e.g. with Kyverno or OPA).
    '';
    default = { };
    example = {
      "repo" = "https://github.com/example/repo";
      "build-system" = "nix";
    };
  };
}
