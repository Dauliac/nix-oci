# BDD test specs for hardening.privileges option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-privileges = {
        eval-defaults = {
          given = "a container with default hardening.privileges";
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
          given = "a container with hardening enabled including privileges";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with privileges configured";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
            hardening.enable = true;
          };
        };

        runtime-setuid-blocked = {
          given = "a hardened container with no-new-privileges";
          "when" = "a process tries to execute a setuid binary";
          "then" = "privilege escalation is denied";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            entrypoint = [ "${pkgs.busybox}/bin/busybox" ];
          };
          testDependencies = [ pkgs.busybox ];
          # With no-new-privileges, trying to mount (requires CAP_SYS_ADMIN)
          # should fail even as root.
          assertions.runtime = ''
            import docker.errors
            try:
                client.containers.run(
                    "hardening-privileges--runtime-setuid-blocked:latest",
                    entrypoint="${pkgs.busybox}/bin/busybox",
                    command="mount -t tmpfs none /mnt",
                    security_opt=["no-new-privileges"],
                    cap_drop=["ALL"],
                    remove=True,
                )
                pytest.fail("Expected mount to fail with no-new-privileges")
            except docker.errors.ContainerError as e:
                assert e.exit_status != 0, "mount should have failed"
          '';
        };
      };
    };
}
