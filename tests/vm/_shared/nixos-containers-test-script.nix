# Shared Python test body for NixOS container tests (jq, devShell, postgres).
# Used by the consolidated NixOS VM test.
''
  def run_nixos_containers_tests(m):
      """Run nixos-containers tests (jq, devShell, postgres)."""

      with subtest("load nixos-container images"):
          for name in ["jq-test", "dev-shell-test", "nixos-postgres"]:
              m.wait_for_unit(f"oci-load-{name}.service")

      # --- jq ---
      with subtest("jq: User is jq"):
          info = image_inspect(m, "jq-test:latest")
          user = info.get("Config", {}).get("User", "")
          assert user == "jq", f"Expected User=jq, got: {user}"

      with subtest("jq: jq binary runs"):
          m.succeed("podman run --rm --entrypoint '/bin/jq' jq-test:latest --version")

      # --- devShell ---
      with subtest("devShell: User is dev"):
          info = image_inspect(m, "dev-shell-test:latest")
          user = info.get("Config", {}).get("User", "")
          assert user == "dev", f"Expected User=dev, got: {user}"

      for binary, name, expected in [
          ("/bin/zsh", "zsh", "zsh"),
          ("/bin/starship", "starship", "starship"),
          ("/bin/nvim", "neovim", "NVIM"),
          ("/bin/git", "git", "git version"),
          ("/bin/rg", "ripgrep", "ripgrep"),
      ]:
          with subtest(f"devShell: {name} runs"):
              result = m.succeed(
                  f"podman run --rm --entrypoint '{binary}' dev-shell-test:latest --version"
              )
              assert expected in result, f"Expected '{expected}' in output, got: {result[:200]}"

      with subtest("devShell: /etc/passwd has dev user"):
          _cp_counter[0] += 1
          cname = f"img-cp-{_cp_counter[0]}"
          m.succeed(f"podman create --name {cname} dev-shell-test:latest true")
          content = m.succeed(f"podman cp {cname}:/etc/passwd -")
          m.succeed(f"podman rm {cname}")
          assert "dev" in content, f"passwd should contain dev user, got: {content[:200]}"

      with subtest("devShell: /home/dev exists"):
          m.succeed("podman run --rm --entrypoint '/bin/ls' dev-shell-test:latest -d /home/dev")

      # --- postgres ---
      with subtest("postgres: postgres binary runs"):
          result = m.succeed(
              "podman run --rm --entrypoint '/bin/postgres' nixos-postgres:latest --version"
          )
          assert "postgres" in result, f"Expected 'postgres' in output, got: {result}"

      with subtest("postgres: pg_hba.conf exists"):
          _cp_counter[0] += 1
          cname = f"img-cp-{_cp_counter[0]}"
          m.succeed(f"podman create --name {cname} nixos-postgres:latest true")
          content = m.succeed(f"podman cp {cname}:/etc/postgresql/pg_hba.conf -")
          m.succeed(f"podman rm {cname}")
          assert len(content) > 0, "pg_hba.conf should exist and have content"
''
