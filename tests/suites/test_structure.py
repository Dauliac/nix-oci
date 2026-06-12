"""Image structure tests -- metadata, user, binary execution."""


class TestMinimalist:
    IMAGE = "minimalist:latest"

    def test_user_is_kubectl(self, image_helper):
        image_helper(self.IMAGE).assert_user("kubectl")

    def test_kubectl_runs(self, run_container):
        run_container(self.IMAGE, "/bin/kubectl", "version --client")


class TestMinimalistWithDeps:
    IMAGE = "minimalist-with-deps:latest"

    def test_user_is_kubectl(self, image_helper):
        image_helper(self.IMAGE).assert_user("kubectl")

    def test_kubectl_runs(self, run_container):
        run_container(self.IMAGE, "/bin/kubectl", "version --client")

    def test_bash_runs(self, run_container):
        run_container(self.IMAGE, "/bin/bash", "--version")

    def test_kubectl_cnpg_runs(self, run_container):
        run_container(self.IMAGE, "/bin/kubectl-cnpg", "version")


class TestMinimalistWithName:
    IMAGE = "hola:latest"  # image name override via oci.containers.*.name

    def test_user_is_hello(self, image_helper):
        image_helper(self.IMAGE).assert_user("hello")

    def test_hello_runs(self, run_container):
        run_container(self.IMAGE, "/bin/hello")


class TestWithRootUser:
    IMAGE = "with-root-user:latest"

    def test_user_is_root(self, image_helper):
        image_helper(self.IMAGE).assert_user("root")

    def test_bash_runs(self, run_container):
        run_container(self.IMAGE, "/bin/bash", "--version")

    def test_coreutils_ls_runs(self, run_container):
        run_container(self.IMAGE, "/bin/ls", "--version")

    def test_whoami_is_root(self, run_container):
        output = run_container(self.IMAGE, "/bin/whoami")
        assert "root" in output


class TestWriteShellScriptBin:
    IMAGE = "write-shell-script-bin:latest"

    def test_user_is_hello_script(self, image_helper):
        image_helper(self.IMAGE).assert_user("hello-script")

    def test_runs_with_expected_output(self, run_container):
        output = run_container(self.IMAGE, "/bin/hello-script")
        assert "Hello from writeShellScriptBin!" in output


class TestWriteShellApplication:
    IMAGE = "write-shell-application:latest"

    def test_user_is_hello_app(self, image_helper):
        image_helper(self.IMAGE).assert_user("hello-app")

    def test_runs_with_expected_output(self, run_container):
        output = run_container(self.IMAGE, "/bin/hello-app")
        assert "Hello from writeShellApplication!" in output
