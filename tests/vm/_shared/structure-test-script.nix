# Shared Python test body for image structure tests.
#
# Defines helper functions and run_structure_tests(m) which runs all
# structure subtests on the given machine object.
# Used by both NixOS and system-manager backends.
''
  # json is imported in sharedAssertions (loaded first).


  def wait_for_load(m, name):
      """Wait for the oci-load service to complete."""
      m.wait_for_unit(f"oci-load-{name}.service")


  def image_inspect(m, image_ref):
      """Return parsed podman image inspect output."""
      raw = m.succeed(f"podman image inspect {image_ref}")
      return json.loads(raw)[0]


  def assert_user(m, image_ref, expected_user):
      """Assert the OCI User config field matches."""
      info = image_inspect(m, image_ref)
      user = info.get("Config", {}).get("User", "")
      assert user == expected_user, \
          f"Expected User={expected_user} in {image_ref}, got: {user}"


  def run_entrypoint(m, image_ref, binary, args=""):
      """Run a specific binary as entrypoint (works without coreutils)."""
      return m.succeed(
          f"podman run --rm --entrypoint '{binary}' {image_ref} {args}"
      )


  def assert_binary_runs(m, image_ref, binary, args=""):
      """Assert a binary can be executed inside the image."""
      run_entrypoint(m, image_ref, binary, args)


  def assert_entrypoint_output(m, image_ref, binary, args, expected):
      """Assert binary output contains expected string."""
      result = run_entrypoint(m, image_ref, binary, args)
      assert expected in result, \
          f"Expected '{expected}' in output of '{binary} {args}', got: {result}"


  def run_structure_tests(m):
      """Run all structure tests on machine m."""

      # Load all images
      with subtest("load all images"):
          for name in [
              "minimalist",
              "minimalist-with-deps",
              "minimalist-with-name",
              "with-root-user",
              "write-shell-script-bin",
              "write-shell-application",
          ]:
              wait_for_load(m, name)

      # --- minimalist (kubectl) ---
      with subtest("minimalist: User is kubectl"):
          assert_user(m, "minimalist:latest", "kubectl")

      with subtest("minimalist: kubectl runs"):
          assert_binary_runs(m, "minimalist:latest", "/bin/kubectl", "version --client")

      # --- minimalist-with-deps (kubectl + bash + kubectl-cnpg) ---
      with subtest("minimalist-with-deps: User is kubectl"):
          assert_user(m, "minimalist-with-deps:latest", "kubectl")

      with subtest("minimalist-with-deps: kubectl runs"):
          assert_binary_runs(
              m, "minimalist-with-deps:latest", "/bin/kubectl", "version --client"
          )

      with subtest("minimalist-with-deps: bash runs"):
          assert_binary_runs(
              m, "minimalist-with-deps:latest", "/bin/bash", "--version"
          )

      with subtest("minimalist-with-deps: kubectl-cnpg runs"):
          assert_binary_runs(
              m, "minimalist-with-deps:latest", "/bin/kubectl-cnpg", "version"
          )

      # --- minimalist-with-name (hello, image named "hola") ---
      with subtest("minimalist-with-name: User is hello"):
          assert_user(m, "hola:latest", "hello")

      with subtest("minimalist-with-name: hello runs"):
          assert_binary_runs(m, "hola:latest", "/bin/hello")

      # --- with-root-user (bash + coreutils, root user) ---
      with subtest("with-root-user: User is root"):
          assert_user(m, "with-root-user:latest", "root")

      with subtest("with-root-user: bash runs"):
          assert_binary_runs(
              m, "with-root-user:latest", "/bin/bash", "--version"
          )

      with subtest("with-root-user: coreutils ls runs"):
          assert_binary_runs(
              m, "with-root-user:latest", "/bin/ls", "--version"
          )

      with subtest("with-root-user: whoami is root"):
          assert_entrypoint_output(
              m, "with-root-user:latest", "/bin/whoami", "", "root"
          )

      # --- write-shell-script-bin ---
      with subtest("write-shell-script-bin: User is hello-script"):
          assert_user(m, "write-shell-script-bin:latest", "hello-script")

      with subtest("write-shell-script-bin: runs with expected output"):
          assert_entrypoint_output(
              m,
              "write-shell-script-bin:latest",
              "/bin/hello-script",
              "",
              "Hello from writeShellScriptBin!",
          )

      # --- write-shell-application ---
      with subtest("write-shell-application: User is hello-app"):
          assert_user(m, "write-shell-application:latest", "hello-app")

      with subtest("write-shell-application: runs with expected output"):
          assert_entrypoint_output(
              m,
              "write-shell-application:latest",
              "/bin/hello-app",
              "",
              "Hello from writeShellApplication!",
          )
''
