"""Validate nix-oci container in rootless podman via CLI + JSON parsing.

Checks: image presence, container running, inspect, exec capability.
Designed to run inside a NixOS VM test as a non-root user.
"""

import json
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


# --- Image checks ---
images = json.loads(run("podman images --format json"))
image_names: list[str] = []
for img in images:
    for key in ("Names", "names", "RepoTags"):
        if key in img and img[key]:
            image_names.extend(img[key])
print(f"[podman-cli] Images: {image_names}")
assert any(
    "test-http-server" in n for n in image_names
), f"test-http-server not found in {image_names}"

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
    "test-http" in n for n in container_names
), f"test-http not found in {container_names}"

# --- Inspect ---
inspect = json.loads(run("podman inspect test-http"))
state = inspect[0].get("State", {})
running = state.get("Running", False) or state.get("Status") == "running"
assert running, f"Container not running: {state}"
print(f"[podman-cli] Container test-http: running, pid={state.get('Pid', 'N/A')}")

# --- Exec ---
output = run("podman exec test-http echo container-exec-ok")
assert "container-exec-ok" in output, f"exec output: {output}"
print("[podman-cli] Container exec: OK")

print("[podman-cli] All checks passed!")
