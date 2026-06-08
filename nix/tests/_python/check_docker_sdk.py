"""Validate nix-oci container via Docker SDK connected to podman socket.

Checks: image presence, container running, exec capability.
Designed to run inside a NixOS VM test with podman's docker-compatible socket.
"""

import docker

client = docker.DockerClient(base_url="unix:///run/podman/podman.sock")

# --- Image checks ---
images = client.images.list()
image_tags = [tag for img in images for tag in (img.tags or [])]
print(f"[docker-sdk] Images: {image_tags}")
assert any(
    "test-http-server" in tag for tag in image_tags
), f"test-http-server image not found in {image_tags}"

# --- Container checks ---
containers = client.containers.list()
names = [c.name for c in containers]
print(f"[docker-sdk] Running containers: {names}")
assert any(
    "test-http" in name for name in names
), f"test-http container not found in {names}"

# --- Inspect and exec ---
for c in containers:
    if "test-http" in c.name:
        assert c.status == "running", f"Container status: {c.status}"
        state = c.attrs.get("State", {})
        print(
            f"[docker-sdk] Container {c.name}: "
            f"status={c.status}, pid={state.get('Pid', 'N/A')}"
        )

        exit_code, output = c.exec_run("echo container-exec-ok")
        assert exit_code == 0, f"exec failed with code {exit_code}"
        assert b"container-exec-ok" in output, f"exec output: {output}"
        print("[docker-sdk] Container exec: OK")
        break

print("[docker-sdk] All checks passed!")
