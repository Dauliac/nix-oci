{ lib, ... }:
{
  options.test.containerStructureTest.coherence = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to auto-generate a container-structure-test metadata coherence config from the container's declared module options (user, entrypoint, ports, labels, env, workingDir, volumes). Composes with any user-provided `configs`.";
    default = false;
  };
}
