# Shared Python assertion helpers for deploy integration tests.
#
# Returns a Python code string that can be prepended to any testScript.
# The helpers are backend-agnostic: they work with both NixOS VM tests
# (machine object named `machine`) and nix-vm-test VMs (named `vm`).
# The caller passes the machine object explicitly.
''
import json


def assert_load_service(machine, container_name, user=None):
    """Verify oci-load service is active oneshot with RemainAfterExit."""
    svc = f"oci-load-{container_name}.service"
    if user:
        machine.wait_for_unit(svc, user)
        props = machine.succeed(
            f"su - {user} -c '"
            f"XDG_RUNTIME_DIR=/run/user/$(id -u) "
            f"systemctl --user show {svc} "
            f"--property=Type,RemainAfterExit,ActiveState'"
        )
    else:
        machine.wait_for_unit(svc)
        props = machine.succeed(
            f"systemctl show {svc} --property=Type,RemainAfterExit,ActiveState"
        )
    assert "Type=oneshot" in props, f"Expected Type=oneshot: {props}"
    assert "RemainAfterExit=yes" in props, f"Expected RemainAfterExit=yes: {props}"
    assert "ActiveState=active" in props, f"Expected ActiveState=active: {props}"


def assert_runner_starts(machine, container_name, backend="podman", user=None):
    """Wait for runner service to become active."""
    svc = f"{backend}-{container_name}.service"
    if user:
        machine.wait_for_unit(svc, user)
    else:
        machine.wait_for_unit(svc)


def assert_runner_depends_on_loader(machine, container_name, backend="podman", user=None):
    """Verify runner service depends on loader."""
    runner = f"{backend}-{container_name}.service"
    loader = f"oci-load-{container_name}.service"
    if user:
        deps = machine.succeed(
            f"su - {user} -c '"
            f"XDG_RUNTIME_DIR=/run/user/$(id -u) "
            f"systemctl --user show {runner} --property=After,Requires'"
        )
    else:
        deps = machine.succeed(
            f"systemctl show {runner} --property=After,Requires"
        )
    assert loader in deps, f"Runner must depend on loader: {deps}"


def assert_image_loaded(machine, container_name, user=None):
    """Verify image is present in podman."""
    if user:
        images_json = machine.succeed(
            f"su - {user} -c 'podman images --format json'"
        )
    else:
        images_json = machine.succeed("podman images --format json")
    images = json.loads(images_json)
    names = []
    for img in images:
        for key in ("Names", "names", "RepoTags"):
            if key in img and img[key]:
                names.extend(img[key])
    assert any(container_name in n for n in names), \
        f"{container_name} image not found: {names}"


def assert_http_responds(machine, port, expected_content, path="/index.html"):
    """Verify HTTP server responds with expected content."""
    machine.wait_for_open_port(port)
    machine.wait_until_succeeds(
        f"curl -sf http://localhost:{port}{path}", timeout=30
    )
    response = machine.succeed(f"curl -sf http://localhost:{port}{path}")
    assert expected_content in response, f"Bad response: {response}"


def assert_container_exec(machine, container_name, command="echo exec-ok", expected="exec-ok", user=None):
    """Run command inside container and check output."""
    if user:
        result = machine.succeed(
            f"su - {user} -c 'podman exec {container_name} {command}'"
        )
    else:
        result = machine.succeed(f"podman exec {container_name} {command}")
    assert expected in result, f"Expected '{expected}' in exec output: {result}"
''
