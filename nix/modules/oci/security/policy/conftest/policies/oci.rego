# Built-in nix-oci Conftest policies for OCI image config.
#
# Input is the nix2container image.json directly.
# Available: input["image-config"] (OCI config), input.layers (layer paths).
package main

import rego.v1

_config := input["image-config"]
_layers := input.layers

# ══════════════════════════════════════════════════════════════
# USER
# ══════════════════════════════════════════════════════════════

# Deny containers with empty user (defaults to root at runtime)
deny contains msg if {
	_config.User == ""
	msg := "container User is empty — defaults to root at runtime"
}

# Deny containers explicitly running as root
deny contains msg if {
	_config.User in {"root", "0", "0:0"}
	msg := sprintf("container must not run as root (User is '%s')", [_config.User])
}

# ══════════════════════════════════════════════════════════════
# ENTRYPOINT
# ══════════════════════════════════════════════════════════════

# Deny images with no entrypoint
deny contains msg if {
	not _config.Entrypoint
	msg := "image has no Entrypoint set"
}

deny contains msg if {
	_config.Entrypoint
	count(_config.Entrypoint) == 0
	msg := "image Entrypoint is empty"
}

# Deny entrypoint binary not present in any layer
deny contains msg if {
	_config.Entrypoint
	count(_config.Entrypoint) > 0
	ep := _config.Entrypoint[0]
	startswith(ep, "/nix/store/")
	# Extract the store path (first 3 components: /nix/store/hash-name)
	parts := split(ep, "/")
	store_path := sprintf("/%s/%s/%s", [parts[1], parts[2], parts[3]])
	not _store_path_in_layers(store_path)
	msg := sprintf("entrypoint store path '%s' not found in any layer", [store_path])
}

# ══════════════════════════════════════════════════════════════
# ENVIRONMENT
# ══════════════════════════════════════════════════════════════

# Deny secrets leaked in environment variables
_secret_patterns := [
	"PASSWORD",
	"SECRET",
	"PRIVATE_KEY",
	"API_KEY",
	"TOKEN",
	"CREDENTIALS",
]

deny contains msg if {
	some env in _config.Env
	key := split(env, "=")[0]
	some pattern in _secret_patterns
	contains(upper(key), pattern)
	parts := split(env, "=")
	count(parts) > 1
	parts[1] != ""
	msg := sprintf("env var '%s' may leak a secret (contains '%s' in name)", [key, pattern])
}

# ══════════════════════════════════════════════════════════════
# LABELS
# ══════════════════════════════════════════════════════════════

# Warn on missing OCI standard labels
warn contains msg if {
	not _has_label("org.opencontainers.image.source")
	msg := "missing recommended label: org.opencontainers.image.source"
}

warn contains msg if {
	not _has_label("org.opencontainers.image.description")
	msg := "missing recommended label: org.opencontainers.image.description"
}

warn contains msg if {
	not _has_label("org.opencontainers.image.title")
	msg := "missing recommended label: org.opencontainers.image.title"
}

# ══════════════════════════════════════════════════════════════
# STOP SIGNAL
# ══════════════════════════════════════════════════════════════

# Warn if StopSignal is SIGKILL (no graceful shutdown)
warn contains msg if {
	_config.StopSignal == "SIGKILL"
	msg := "StopSignal is SIGKILL — container cannot shut down gracefully"
}

warn contains msg if {
	_config.StopSignal == "9"
	msg := "StopSignal is 9 (SIGKILL) — container cannot shut down gracefully"
}

# ══════════════════════════════════════════════════════════════
# LAYERS
# ══════════════════════════════════════════════════════════════

# Warn if image has too many layers (overlayfs limit is 128)
warn contains msg if {
	count(_layers) > 100
	msg := sprintf("image has %d layers (overlayfs limit is 128)", [count(_layers)])
}

# ══════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════

_has_label(key) if {
	_config.Labels[key]
}

# Check if a nix store path is present in any layer
_store_path_in_layers(store_path) if {
	some layer in _layers
	some p in layer.paths
	p.path == store_path
}
