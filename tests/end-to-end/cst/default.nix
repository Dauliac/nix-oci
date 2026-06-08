{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          minimalist = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./minimalist.yaml
              ];
            };
          };
          minimalistWithDependencies = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./minimalistWithDependencies.yaml
              ];
            };
          };
          withRootUserAndPackage = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./withRootUserAndPackage.yaml
              ];
            };
          };
          write-shell-application = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./write-shell-application.yaml
              ];
            };
          };
          write-shell-script-bin = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./write-shell-script-bin.yaml
              ];
            };
          };
          minimalistWithName = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./minimalistWithName.yaml
              ];
            };
          };
          crossBuildKubectl = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./crossBuildKubectl.yaml
              ];
            };
          };
        };
      };
  };
}
