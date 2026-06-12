# Policy gate functions: collect enabled pure policy runners and gate images
{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
in
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.test = {
        mkPolicyGate = {
          type = types.functionTo types.package;
          description = "Collect enabled pure policy runners and build a gate stamp.";
          file = "nix/modules/oci/testing/gate.nix";
          fn =
            {
              runners,
              containerId,
            }:
            let
              enabledPure = lib.filterAttrs (_: r: r.enabled && r.tier == "pure") runners;
              stamps = lib.mapAttrsToList (name: r: r.mkStamp { inherit containerId; }) enabledPure;
            in
            pkgs.runCommandLocal "policy-gate-${containerId}" { } ''
              ${lib.concatMapStrings (s: ": ${s}\n") stamps}
              touch $out
            '';
        };

        mkGatedImage = {
          type = types.functionTo types.package;
          description = "Create a gated image that depends on the policy gate stamp.";
          file = "nix/modules/oci/testing/gate.nix";
          fn =
            {
              gateStamp,
              ociImage,
              containerId,
            }:
            pkgs.runCommandLocal "gated-${containerId}" { } ''
              : ${gateStamp}
              ln -s ${ociImage} $out
            '';
        };
      };
    };
}
