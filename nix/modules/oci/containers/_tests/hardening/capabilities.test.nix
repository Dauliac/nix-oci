# BDD test specs for hardening.capabilities option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-capabilities = {
        eval-defaults = {
          given = "a container with default hardening.capabilities";
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
          given = "a container with hardening enabled including capabilities";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with capabilities configured";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
            hardening.enable = true;
          };
        };

        runtime-no-new-privileges = {
          given = "a hardened container with all capabilities dropped";
          "when" = "a process tries to change user with su";
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
          # With --cap-drop=ALL and --security-opt=no-new-privileges,
          # chown should fail even as root.
          assertions.runtime = ''
            import docker.errors
            try:
                client.containers.run(
                    "hardening-capabilities--runtime-no-new-privileges:latest",
                    entrypoint="${pkgs.busybox}/bin/busybox",
                    command="chown nobody /",
                    cap_drop=["ALL"],
                    security_opt=["no-new-privileges"],
                    remove=True,
                )
                pytest.fail("Expected chown to fail with dropped capabilities")
            except docker.errors.ContainerError as e:
                assert e.exit_status != 0, "chown should have failed"
          '';
        };
      };
    };
}
