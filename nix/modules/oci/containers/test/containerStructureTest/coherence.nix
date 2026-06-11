# Container test.containerStructureTest.coherence option
{
  lib,
  config,
  ...
}:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.test.containerStructureTest.coherence = lib.mkOption {
            type = lib.types.bool;
            description = ''
              Auto-generate a CST metadataTest config from the container's
              module config. This validates that the built OCI artifact
              matches the declared user, entrypoint, ports, labels,
              environment, working directory, and volumes.
            '';
            default = true;
          };
        };
    };
}
