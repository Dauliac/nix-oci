"""Validate nix-oci container in rootless podman via CLI + JSON parsing.

Checks: systemd user services, image presence, container running,
inspect, exec capability.
Designed to run inside a NixOS VM test as a non-root user.
"""

import json
import os
import subprocess
import sys


def run(cmd: str) -> str:
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(
            f"FAIL: {cmd}\nstdout: {result.stdout}\nstderr: {result.stderr}",
            file=sys.stderr,
        )
        sys.exit(1)
    return result.stdout


def check_user_service(name: str, expected_active: str = "active") -> None:
    result = subprocess.run(
        ["systemctl", "--user", "show", name, "--property=ActiveState"],
        capture_output=True,
        text=True,
        env={**os.environ, "XDG_RUNTIME_DIR": f"/run/user/{os.getuid()}"},
    )
    assert result.returncode == 0, f"Failed to query {name}: {result.stderr}"
    assert f"ActiveState={expected_active}" in result.stdout, (
        f"{name} not {expected_active}: {result.stdout}"
    )


# --- Systemd user service checks ---
print("[podman-cli] Checking systemd user services...")
check_user_service("oci-load-http-server.service", "active")
check_user_service("podman-http-server.service", "active")

env = {**os.environ, "XDG_RUNTIME_DIR": f"/run/user/{os.getuid()}"}

# Verify loader is oneshot
result = subprocess.run(
    ["systemctl", "--user", "show", "oci-load-http-server.service", "--property=Type"],
    capture_output=True,
    text=True,
    env=env,
)
assert "Type=oneshot" in result.stdout, f"Expected oneshot: {result.stdout}"

# Verify runner depends on loader
result = subprocess.run(
    [
        "systemctl",
        "--user",
        "show",
        "podman-http-server.service",
        "--property=After,Requires",
    ],
    capture_output=True,
    text=True,
    env=env,
)
assert "oci-load-http-server.service" in result.stdout, (
    f"Runner must depend on loader: {result.stdout}"
)
print("[podman-cli] Systemd user services: OK")

# --- Image checks ---
images = json.loads(run("podman images --format json"))
image_names: list[str] = []
for img in images:
    for key in ("Names", "names", "RepoTags"):
        if key in img and img[key]:
            image_names.extend(img[key])
print(f"[podman-cli] Images: {image_names}")
assert any(
    "http-server" in n for n in image_names
), f"http-server not found in {image_names}"

# --- Container checks ---
containers = json.loads(run("podman ps --format json"))
container_names: list[str] = []
for c in containers:
    name = c.get("Names", c.get("Name", ""))
    if isinstance(name, list):
        container_names.extend(name)
    else:
        container_names.append(name)
print(f"[podman-cli] Running containers: {container_names}")
assert any(
    "http-server" in n for n in container_names
), f"http-server not found in {container_names}"

# --- Inspect ---
inspect = json.loads(run("podman inspect http-server"))
state = inspect[0].get("State", {})
running = state.get("Running", False) or state.get("Status") == "running"
assert running, f"Container not running: {state}"
print(f"[podman-cli] Container http-server: running, pid={state.get('Pid', 'N/A')}")

# --- Exec ---
output = run("podman exec http-server echo container-exec-ok")
assert "container-exec-ok" in output, f"exec output: {output}"
print("[podman-cli] Container exec: OK")

print("[podman-cli] All checks passed!")
