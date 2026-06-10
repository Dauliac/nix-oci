{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        # Basic structure tests migrated to VM: tests/vm/structure.nix
        # (minimalist, minimalistWithDependencies, minimalistWithName,
        #  withRootUserAndPackage, write-shell-script-bin, write-shell-application)
        config.oci.containers = {
          crossBuildJq = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./crossBuildJq.yaml
              ];
            };
          };
          devShell = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./devShell.yaml
              ];
            };
          };
          nixosPostgres = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./nixosPostgres.yaml
              ];
            };
          };
          hardeningDnsDisabled = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./hardeningDnsDisabled.yaml
              ];
            };
          };
          hardeningNoTls = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./hardeningNoTls.yaml
              ];
            };
          };
          hardeningFull = {
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./hardeningFull.yaml
              ];
            };
          };
        };
      };
  };
}
