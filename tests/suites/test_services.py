"""NixOS container tests -- jq, devShell, postgres.

These tests only run on the NixOS backend (the containers require
nixosConfig and homeConfig which system-manager may not provide).
"""

import pytest


@pytest.fixture(autouse=True, scope="module")
def _require_nixos(nixos_only):
    """Skip this entire module on non-NixOS backends."""


class TestJq:
    IMAGE = "jq-test:latest"

    def test_user_is_jq(self, image_helper):
        image_helper(self.IMAGE).assert_user("jq")

    def test_jq_runs(self, run_container):
        run_container(self.IMAGE, "/bin/jq", "--version")


class TestDevShell:
    IMAGE = "dev-shell-test:latest"

    def test_user_is_dev(self, image_helper):
        image_helper(self.IMAGE).assert_user("dev")

    @pytest.mark.parametrize(
        "binary,expected",
        [
            ("/bin/zsh", "zsh"),
            ("/bin/starship", "starship"),
            ("/bin/nvim", "NVIM"),
            ("/bin/git", "git version"),
            ("/bin/rg", "ripgrep"),
        ],
    )
    def test_tool_runs(self, run_container, binary, expected):
        output = run_container(self.IMAGE, binary, "--version")
        assert expected in output

    def test_passwd_has_dev_user(self, image_helper):
        content = image_helper(self.IMAGE).read_file("/etc/passwd")
        assert "dev" in content

    def test_home_dev_exists(self, run_container):
        run_container(self.IMAGE, "/bin/ls", "-d /home/dev")


class TestPostgres:
    IMAGE = "nixos-postgres:latest"

    def test_postgres_runs(self, run_container):
        output = run_container(self.IMAGE, "/bin/postgres", "--version")
        assert "postgres" in output

    def test_pg_hba_conf_exists(self, image_helper):
        content = image_helper(self.IMAGE).read_file("/etc/postgresql/pg_hba.conf")
        assert len(content) > 0, "pg_hba.conf should exist and have content"
