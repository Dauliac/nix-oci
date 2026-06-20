# Auto-generate CST metadataTest config from container module config.
#
# Produces a JSON file that container-structure-test consumes.  The test
# validates that the built OCI artifact matches the user-declared config
# (user, entrypoint, ports, labels, env, workdir, volumes).
{
  lib,
  config,
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
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
    in
    {
      nix-lib.lib.oci.mkCoherenceCst = {
        type = types.functionTo types.package;
        description = "Auto-generate CST metadataTest JSON from container module config";
        file = "nix/modules/oci/testing/container-structure/coherence.nix";
        fn =
          {
            perSystemConfig,
            containerId,
          }:
          let
            oci = perSystemConfig.containers.${containerId};
            out = oci.nixosConfig.eval.oci.container._output;

            # Same entrypoint resolution as mkSimpleOCI.nix:99
            finalEntrypoint = if out.entrypoint != [ ] then out.entrypoint else oci.entrypoint;

            # Parse "host:container" port mappings to container ports
            parsePort =
              p:
              let
                parts = lib.splitString ":" p;
              in
              lib.last parts;
            containerPorts = map parsePort (oci.ports or [ ]);

            # Parse "KEY=VALUE" env strings (handles values containing '=')
            parseEnv =
              envStr:
              let
                parts = lib.splitString "=" envStr;
                key = builtins.head parts;
                value = lib.concatStringsSep "=" (builtins.tail parts);
              in
              {
                inherit key value;
              };

            # User-declared labels only (auto-labels validated by option tests)
            userLabels = oci.labels or { };

            metadataTest =
              { }
              // lib.optionalAttrs (oci.user != "") { user = oci.user; }
              // lib.optionalAttrs (finalEntrypoint != [ ]) { entrypoint = finalEntrypoint; }
              // lib.optionalAttrs (containerPorts != [ ]) { exposedPorts = containerPorts; }
              // lib.optionalAttrs (userLabels != { }) {
                labels = lib.mapAttrsToList (k: v: {
                  key = k;
                  value = v;
                }) userLabels;
              }
              // lib.optionalAttrs (out.envVars != [ ]) {
                env = map parseEnv out.envVars;
              }
              // lib.optionalAttrs ((out.workingDir or null) != null) {
                workdir = out.workingDir;
              }
              // lib.optionalAttrs ((out.declaredVolumes or [ ]) != [ ]) {
                volumes = out.declaredVolumes;
              };

            cstConfig = {
              inherit metadataTest;
            };
          in
          pkgs.writeText "cst-coherence-${containerId}.json" (builtins.toJSON cstConfig);
      };
    };
}
