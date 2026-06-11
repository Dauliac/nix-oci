# ContainerHelper — Python test class for container assertions.
#
# Wraps NixOS VM test primitives (wait_for_unit, wait_for_open_port,
# wait_until_succeeds) into container-aware operations with built-in
# wait/retry semantics.
#
# Usage in testScript:
#   ${containerHelper}
#   h = ContainerHelper(machine, "my-container", "my-image:latest")
#   h.assert_image_config({"User": "nobody"})
#   h.run_succeeds("/bin/hello")
#
# Imported by:
#   - tests/options/flake-module.nix (generated option tests)
#   - tests/vm/*.nix (hand-written VM tests)
''
  import json
  import shlex


  class ContainerHelper:
      """Container test helper with built-in wait/retry semantics."""

      _cp_counter = 0

      def __init__(self, machine, container_name, image_ref):
          self.m = machine
          self.name = container_name
          self.image = image_ref

      # ── Image-level (no runtime needed) ──────────────────────────

      def image_inspect(self):
          """Return parsed podman image inspect output."""
          raw = self.m.succeed(f"podman image inspect {self.image}")
          return json.loads(raw)[0]

      def assert_image_config(self, expected):
          """Assert OCI image Config fields match expected values.

          expected: dict of Config field name -> expected value.
          Example: {"User": "nobody", "ExposedPorts": {"8080/tcp": {}}}
          """
          info = self.image_inspect()
          config = info.get("Config", {})
          for key, value in expected.items():
              actual = config.get(key)
              assert actual == value, (
                  f"Image {self.image}: expected Config.{key}={value!r}, "
                  f"got: {actual!r}"
              )

      def assert_labels(self, expected):
          """Assert multiple OCI labels match.

          expected: dict of label key -> expected value.
          """
          info = self.image_inspect()
          labels = info.get("Labels", {})
          for key, value in expected.items():
              actual = labels.get(key)
              assert actual == value, (
                  f"Image {self.image}: expected label {key}={value!r}, "
                  f"got: {actual!r}"
              )

      def read_file(self, path):
          """Read a file from the image filesystem (bypasses runtime mounts).

          Uses podman create + cp to read from the image layer directly,
          avoiding bind-mounts that podman injects at runtime.
          """
          ContainerHelper._cp_counter += 1
          cname = f"cp-{self.name}-{ContainerHelper._cp_counter}"
          self.m.succeed(f"podman create --name {cname} {self.image} true")
          content = self.m.succeed(f"podman cp {cname}:{path} -")
          self.m.succeed(f"podman rm {cname}")
          return content

      def assert_file_contains(self, path, expected):
          """Assert a file inside the image contains a string."""
          content = self.read_file(path)
          assert expected in content, (
              f"Image {self.image}: expected {path!r} to contain "
              f"{expected!r}, got: {content[:300]}"
          )

      def assert_file_not_contains(self, path, excluded):
          """Assert a file inside the image does NOT contain a string."""
          content = self.read_file(path)
          assert excluded not in content, (
              f"Image {self.image}: expected {path!r} to NOT contain "
              f"{excluded!r}, got: {content[:300]}"
          )

      # ── Oneshot (podman run --rm) ────────────────────────────────

      def run(self, command, args=""):
          """Run a binary as entrypoint in a throwaway container."""
          cmd = f"podman run --rm --entrypoint {shlex.quote(command)} {self.image}"
          if args:
              cmd += " " + args
          return self.m.succeed(cmd)

      def run_succeeds(self, command, args="", stdout=None):
          """Assert a command runs successfully (exit 0).

          If stdout is provided, also assert output contains the string.
          """
          result = self.run(command, args)
          if stdout:
              assert stdout in result, (
                  f"Container {self.name}: expected {stdout!r} in output "
                  f"of '{command} {args}', got: {result[:300]}"
              )
          return result

      def run_fails(self, command, args="", exit_code=None):
          """Assert a command fails (exit != 0).

          If exit_code is provided, assert the specific exit code.
          """
          cmd = f"podman run --rm --entrypoint {shlex.quote(command)} {self.image}"
          if args:
              cmd += " " + args
          code, output = self.m.execute(cmd)
          assert code != 0, (
              f"Container {self.name}: expected '{command}' to fail, "
              f"but it succeeded with: {output[:200]}"
          )
          if exit_code is not None:
              assert code == exit_code, (
                  f"Container {self.name}: expected exit code {exit_code} "
                  f"from '{command}', got: {code}"
              )

      # ── Daemon (long-running container) ──────────────────────────

      def wait_ready(self, timeout=30):
          """Wait until the container is running."""
          self.m.wait_until_succeeds(
              f"podman inspect {self.name} --format '{{{{.State.Status}}}}' "
              f"| grep -q running",
              timeout=timeout,
          )

      def wait_healthy(self, timeout=60):
          """Wait until the container healthcheck passes."""
          self.m.wait_until_succeeds(
              f"podman inspect {self.name} --format '{{{{.State.Health.Status}}}}' "
              f"| grep -q healthy",
              timeout=timeout,
          )

      def assert_http(self, port, path="/", contains="", timeout=30):
          """Assert an HTTP endpoint responds with expected content.

          Uses wait_for_open_port + wait_until_succeeds for retry.
          """
          self.m.wait_for_open_port(port)
          self.m.wait_until_succeeds(
              f"curl -sf http://localhost:{port}{path}", timeout=timeout
          )
          if contains:
              response = self.m.succeed(
                  f"curl -sf http://localhost:{port}{path}"
              )
              assert contains in response, (
                  f"Container {self.name}: expected {contains!r} in HTTP "
                  f"response from :{port}{path}, got: {response[:300]}"
              )

      def assert_env(self, key, contains):
          """Assert a process env var contains a string.

          Reads from /proc/1/environ (the container's PID 1) to see
          OCI-configured env vars, which may not appear in `env` output.
          """
          raw = self.m.succeed(
              f"podman exec {self.name} cat /proc/1/environ"
          ).replace("\x00", "\n")
          matching = [l for l in raw.strip().split("\n")
                      if l.startswith(f"{key}=")]
          assert matching, (
              f"Container {self.name}: env var {key} not found"
          )
          assert contains in matching[0], (
              f"Container {self.name}: expected {key} to contain "
              f"{contains!r}, got: {matching[0]!r}"
          )

      def container_inspect(self):
          """Return parsed podman container inspect output."""
          raw = self.m.succeed(f"podman inspect {self.name}")
          return json.loads(raw)[0]

      def assert_inspect(self, expected):
          """Assert podman inspect fields match.

          expected: dict of dot-path -> expected value.
          Example: {"HostConfig.LogConfig.Type": "passthrough"}
          """
          data = self.container_inspect()
          for path, value in expected.items():
              actual = data
              for key in path.split("."):
                  actual = actual.get(key, {}) if isinstance(actual, dict) else None
              assert actual == value, (
                  f"Container {self.name}: expected inspect "
                  f"{path}={value!r}, got: {actual!r}"
              )

      def assert_systemd(self, service, expected_props):
          """Assert systemd service properties match.

          expected_props: dict of property name -> expected value string.
          Example: {"Type": "notify", "NotifyAccess": "all"}
          """
          keys = ",".join(expected_props.keys())
          props = self.m.succeed(
              f"systemctl show {service} --property={keys}"
          )
          for key, value in expected_props.items():
              assert f"{key}={value}" in props, (
                  f"Service {service}: expected {key}={value}, "
                  f"in: {props}"
              )

      def exec_succeeds(self, command, stdout=None):
          """Run a command inside the running container."""
          result = self.m.succeed(f"podman exec {self.name} {command}")
          if stdout:
              assert stdout in result, (
                  f"Container {self.name}: expected {stdout!r} in exec "
                  f"output of '{command}', got: {result[:300]}"
              )
          return result

      def exec_fails(self, command, exit_code=None):
          """Assert a command fails inside the running container."""
          code, output = self.m.execute(
              f"podman exec {self.name} {command}"
          )
          assert code != 0, (
              f"Container {self.name}: expected exec '{command}' to fail"
          )
          if exit_code is not None:
              assert code == exit_code, (
                  f"Container {self.name}: expected exit code {exit_code} "
                  f"from exec '{command}', got: {code}"
              )

      def stop(self, timeout=10):
          """Stop the container with a timeout for graceful shutdown."""
          self.m.succeed(f"podman stop -t {timeout} {self.name}")

      def logs(self):
          """Return container logs."""
          return self.m.succeed(f"podman logs {self.name}")
''
