# Built-in nix-oci Conftest policies for OCI image config.
#
# Input is the nix2container image.json directly.
# The config is at input["image-config"].
package main

import rego.v1

_config := input["image-config"]

# Deny containers running as root
deny contains msg if {
	_config.User == "root"
	msg := "container must not run as root (User is 'root')"
}

deny contains msg if {
	_config.User == "0"
	msg := "container must not run as root (User is '0')"
}

deny contains msg if {
	_config.User == "0:0"
	msg := "container must not run as root (User is '0:0')"
}

deny contains msg if {
	_config.User == ""
	msg := "container User is empty — defaults to root at runtime"
}

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

# Warn on missing OCI standard labels
warn contains msg if {
	not _has_label("org.opencontainers.image.source")
	msg := "missing recommended label: org.opencontainers.image.source"
}

warn contains msg if {
	not _has_label("org.opencontainers.image.description")
	msg := "missing recommended label: org.opencontainers.image.description"
}

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

# Helper: check if a label key exists
_has_label(key) if {
	_config.Labels[key]
}
