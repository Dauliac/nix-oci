"""Validate nix-oci container via Docker SDK connected to podman socket.

Checks: image presence, container running, exec capability,
systemd service status, and firewall rules.
Designed to run inside a NixOS VM test with podman's docker-compatible socket.
"""

import docker
import subprocess

client = docker.DockerClient(base_url="unix:///run/podman/podman.sock")

# --- Systemd service checks ---
def check_service(name: str, expected_active: str = "active") -> None:
    result = subprocess.run(
        ["systemctl", "show", name, "--property=ActiveState"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"Failed to query {name}: {result.stderr}"
    assert f"ActiveState={expected_active}" in result.stdout, (
        f"{name} not {expected_active}: {result.stdout}"
    )

print("[docker-sdk] Checking systemd services...")
check_service("oci-load-http-server.service", "active")
check_service("podman-http-server.service", "active")

# Verify loader is oneshot
result = subprocess.run(
    ["systemctl", "show", "oci-load-http-server.service", "--property=Type"],
    capture_output=True,
    text=True,
)
assert "Type=oneshot" in result.stdout, f"Expected oneshot: {result.stdout}"

# Verify runner depends on loader
result = subprocess.run(
    [
        "systemctl",
        "show",
        "podman-http-server.service",
        "--property=After,Requires",
    ],
    capture_output=True,
    text=True,
)
assert "oci-load-http-server.service" in result.stdout, (
    f"Runner must depend on loader: {result.stdout}"
)
print("[docker-sdk] Systemd services: OK")

# --- Firewall checks ---
print("[docker-sdk] Checking firewall rules...")
result = subprocess.run(
    ["iptables", "-L", "INPUT", "-n"],
    capture_output=True,
    text=True,
)
assert result.returncode == 0, f"iptables failed: {result.stderr}"
assert "8080" in result.stdout, (
    f"Firewall should allow port 8080: {result.stdout}"
)
print("[docker-sdk] Firewall rules: OK")

# --- Image checks ---
images = client.images.list()
image_tags = [tag for img in images for tag in (img.tags or [])]
print(f"[docker-sdk] Images: {image_tags}")
assert any(
    "http-server" in tag for tag in image_tags
), f"http-server image not found in {image_tags}"

# --- Container checks ---
containers = client.containers.list()
names = [c.name for c in containers]
print(f"[docker-sdk] Running containers: {names}")
assert any(
    "http-server" in name for name in names
), f"http-server container not found in {names}"

# --- Inspect and exec ---
for c in containers:
    if "http-server" in c.name:
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
