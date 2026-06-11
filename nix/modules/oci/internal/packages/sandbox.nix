{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
  inherit (lib) mkOption types attrsets;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        config,
        pkgs,
        ...
      }:
      let
        ociLib = config.lib.oci or { };
      in
      {
        options.oci.internal = {
          sandboxApps = mkOption {
            description = "Per-container bubblewrap sandbox scripts.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: containerConfig:
              let
                nixosEval = containerConfig.nixosConfig.eval;
                out = nixosEval.oci.container._output;
              in
              ociLib.mkSandboxScript {
                name = containerId;
                rootFilesystem = out.rootFilesystem;
                entrypoint = if out.entrypoint != [ ] then out.entrypoint else containerConfig.entrypoint;
                environment = containerConfig.environment;
                user = nixosEval.oci.container.user;
                isRoot = containerConfig.isRoot;
                workingDir = out.workingDir or containerConfig.workingDir or null;
                inherit pkgs;
              }
            ) config.oci.containers;
          };
          prefixedSandboxApps = mkOption {
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs' (
              name: app:
              attrsets.nameValuePair "oci-sandbox-${name}" {
                type = "app";
                program = lib.getExe app;
              }
            ) config.oci.internal.sandboxApps;
          };
        };
      }
    );
  };
}
