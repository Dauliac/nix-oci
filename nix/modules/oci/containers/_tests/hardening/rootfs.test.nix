# BDD test specs for hardening.rootfs option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-rootfs = {
        eval-defaults = {
          given = "a container with default hardening.rootfs";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
        };

        eval-with-hardening = {
          given = "a container with hardening enabled including rootfs";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with rootfs configured";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
            hardening.enable = true;
          };
        };

        runtime-write-blocked = {
          given = "a hardened container with read-only rootfs";
          "when" = "a process tries to write to the root filesystem";
          "then" = "the write is denied (EROFS)";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            entrypoint = [ "${pkgs.busybox}/bin/busybox" ];
          };
          testDependencies = [ pkgs.busybox ];
          # The succeeds/fails helpers don't pass --read-only to podman,
          # so we use the runtime escape hatch to set read_only=True.
          assertions.runtime = ''
            import docker.errors
            try:
                client.containers.run(
                    "hardening-rootfs--runtime-write-blocked:latest",
                    entrypoint="${pkgs.busybox}/bin/busybox",
                    command="touch /should-fail",
                    read_only=True,
                    remove=True,
                )
                pytest.fail("Expected write to fail on read-only rootfs")
            except docker.errors.ContainerError as e:
                assert e.exit_status != 0, "touch should have failed"
          '';
        };
      };
    };
}
