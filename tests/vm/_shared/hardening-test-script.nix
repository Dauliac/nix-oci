# Shared Python test body for hardening tests.
#
# Defines helper functions and run_hardening_tests(m) which runs all
# hardening subtests on the given machine object.
# Used by both NixOS and system-manager backends.
''
  import shlex

  NS = "io.github.dauliac.nix-oci"

  # wait_for_load and image_inspect are defined in structure-test-script.nix
  # (loaded first in the consolidated test).


  def assert_label(m, image_ref, key, value):
      """Assert an OCI label matches expected value."""
      info = image_inspect(m, image_ref)
      labels = info.get("Labels", {})
      actual = labels.get(key, None)
      assert actual == value, \
          f"Expected label {key}={value} in {image_ref}, got: {actual}"


  def run_ep(m, image_ref, binary, args=""):
      """Run a binary as entrypoint in a throwaway container."""
      cmd = "podman run --rm --entrypoint " + repr(binary) + " " + image_ref
      if args:
          cmd += " " + args
      return m.succeed(cmd)


  def run_sh(m, image_ref, script):
      """Run a shell script inside the container via busybox sh."""
      cmd = f"podman run --rm --entrypoint /bin/sh {image_ref} -c {shlex.quote(script)}"
      return m.succeed(cmd)


  _cp_counter = [0]


  def read_image_file(m, image_ref, path):
      """Read a file from the image filesystem (bypasses runtime mounts).

      Uses podman create + cp to read files from the image layer
      directly, avoiding bind-mounts that podman injects at runtime
      (resolv.conf, hostname, hosts).
      """
      _cp_counter[0] += 1
      cname = f"img-cp-{_cp_counter[0]}"
      m.succeed(f"podman create --name {cname} {image_ref} true")
      content = m.succeed(f"podman cp {cname}:{path} -")
      m.succeed(f"podman rm {cname}")
      return content


  def assert_file_contains(m, image_ref, path, expected):
      """Assert a file inside the image contains a string."""
      content = read_image_file(m, image_ref, path)
      assert expected in content, \
          f"Expected '{expected}' in {path}, got: {content[:200]}"


  def assert_file_not_contains(m, image_ref, path, excluded):
      """Assert a file inside the image does NOT contain a string."""
      content = read_image_file(m, image_ref, path)
      assert excluded not in content, \
          f"Did not expect '{excluded}' in {path}, got: {content[:200]}"


  def run_hardening_tests(m):
      """Run all hardening tests on machine m."""

      # Load all images
      with subtest("load all hardening images"):
          for name in [
              "hardening-dns-disabled",
              "hardening-no-tls",
              "hardening-full",
              "hardening-seccomp-enforce",
              "hardening-database",
              "hardening-audit",
          ]:
              wait_for_load(m, name)

      # --- hardening-dns-disabled ---
      with subtest("dns-disabled: hardening labels"):
          assert_label(
              m, "hardening-dns-disabled:latest",
              f"{NS}.hardening.enabled", "true",
          )
          assert_label(
              m, "hardening-dns-disabled:latest",
              f"{NS}.hardening.dns-disabled", "true",
          )

      with subtest("dns-disabled: nsswitch.conf has files-only hosts"):
          content = read_image_file(m, "hardening-dns-disabled:latest", "/etc/nsswitch.conf")
          assert "hosts:" in content, \
              f"nsswitch.conf missing hosts line: {content}"
          assert "hosts:     files dns" not in content, \
              f"nsswitch.conf should not have dns backend: {content}"

      with subtest("dns-disabled: nsswitch hosts has no dns backend"):
          content = read_image_file(m, "hardening-dns-disabled:latest", "/etc/nsswitch.conf")
          for line in content.splitlines():
              if line.startswith("hosts:"):
                  assert " dns" not in line.split("#")[0], \
                      f"hosts line should not contain dns: {line}"

      with subtest("dns-disabled: busybox runs"):
          run_ep(m, "hardening-dns-disabled:latest", "/bin/busybox", "--help")

      # --- hardening-no-tls ---
      with subtest("no-tls: hardening labels"):
          assert_label(
              m, "hardening-no-tls:latest",
              f"{NS}.hardening.enabled", "true",
          )
          assert_label(
              m, "hardening-no-tls:latest",
              f"{NS}.hardening.tls-trust-store-removed", "true",
          )

      with subtest("no-tls: ca-bundle.crt has removal marker"):
          assert_file_contains(
              m, "hardening-no-tls:latest",
              "/etc/ssl/certs/ca-bundle.crt",
              "TLS trust store removed by nix-oci hardening",
          )

      with subtest("no-tls: ca-bundle.crt has no real certificates"):
          assert_file_not_contains(
              m, "hardening-no-tls:latest",
              "/etc/ssl/certs/ca-bundle.crt",
              "BEGIN CERTIFICATE",
          )

      with subtest("no-tls: busybox runs"):
          run_ep(m, "hardening-no-tls:latest", "/bin/busybox", "--help")

      # --- hardening-full ---
      with subtest("full: all hardening labels present"):
          img = "hardening-full:latest"
          assert_label(m, img, f"{NS}.hardening.enabled", "true")
          assert_label(m, img, f"{NS}.hardening.no-new-privileges", "true")
          assert_label(m, img, f"{NS}.hardening.read-only-rootfs", "true")
          assert_label(m, img, f"{NS}.hardening.capabilities-drop", "ALL")
          assert_label(m, img, f"{NS}.hardening.capabilities-add", "NET_BIND_SERVICE")
          assert_label(m, img, f"{NS}.hardening.seccomp-profile", "strict")
          assert_label(m, img, f"{NS}.hardening.dns-disabled", "true")
          assert_label(m, img, f"{NS}.hardening.tls-trust-store-removed", "true")

      with subtest("full: DNS hardening - nsswitch no dns backend"):
          content = read_image_file(m, "hardening-full:latest", "/etc/nsswitch.conf")
          for line in content.splitlines():
              if line.startswith("hosts:"):
                  assert " dns" not in line.split("#")[0], \
                      f"hosts line should not contain dns: {line}"

      with subtest("full: TLS hardening - ca-bundle neutered"):
          assert_file_contains(
              m, "hardening-full:latest",
              "/etc/ssl/certs/ca-bundle.crt",
              "TLS trust store removed by nix-oci hardening",
          )

      with subtest("full: TLS hardening - no real certificates"):
          assert_file_not_contains(
              m, "hardening-full:latest",
              "/etc/ssl/certs/ca-bundle.crt",
              "BEGIN CERTIFICATE",
          )

      with subtest("full: busybox runs"):
          run_ep(m, "hardening-full:latest", "/bin/busybox", "--help")

      with subtest("full: passwd file has entries"):
          content = read_image_file(m, "hardening-full:latest", "/etc/passwd")
          lines = [l for l in content.splitlines() if l.strip()]
          assert len(lines) > 0, "passwd should have entries"

      # --- hardening-seccomp-enforce ---
      with subtest("seccomp-enforce: load image"):
          wait_for_load(m, "hardening-seccomp-enforce")

      with subtest("seccomp-enforce: io_uring_setup returns EPERM"):
          exit_code = m.execute(
              "podman run --rm --entrypoint /bin/try-io-uring "
              "hardening-seccomp-enforce:latest"
          )[0]
          assert exit_code == 1, \
              f"Expected exit code 1 (EPERM from seccomp), got {exit_code}"

      with subtest("seccomp-enforce: busybox still works"):
          run_ep(m, "hardening-seccomp-enforce:latest", "/bin/busybox", "--help")

      # --- hardening-database ---
      with subtest("database: load image"):
          wait_for_load(m, "hardening-database")

      with subtest("database: seccomp-profile label is database"):
          assert_label(
              m, "hardening-database:latest",
              f"{NS}.hardening.seccomp-profile", "database",
          )

      with subtest("database: hardening enabled label"):
          assert_label(
              m, "hardening-database:latest",
              f"{NS}.hardening.enabled", "true",
          )

      with subtest("database: busybox runs"):
          run_ep(m, "hardening-database:latest", "/bin/busybox", "--help")

      # --- hardening-audit ---
      with subtest("audit: load image"):
          wait_for_load(m, "hardening-audit")

      with subtest("audit: seccomp-profile label is strict"):
          assert_label(
              m, "hardening-audit:latest",
              f"{NS}.hardening.seccomp-profile", "strict",
          )

      with subtest("audit: busybox runs (not blocked by seccomp)"):
          run_ep(m, "hardening-audit:latest", "/bin/busybox", "--help")
''
