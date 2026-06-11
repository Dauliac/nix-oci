# Built-in nix-oci Conftest policies for OCI image config.
#
# These rules validate the OCI image configuration JSON extracted from
# the docker archive. The input schema matches the Docker/OCI image
# config spec (config.User, config.Env, config.Labels, etc.).
package main

# Deny containers running as root
deny[msg] {
	input.config.User == "root"
	msg := "container must not run as root (User is 'root')"
}

deny[msg] {
	input.config.User == "0"
	msg := "container must not run as root (User is '0')"
}

deny[msg] {
	input.config.User == "0:0"
	msg := "container must not run as root (User is '0:0')"
}

deny[msg] {
	input.config.User == ""
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

deny[msg] {
	some i
	env := input.config.Env[i]
	key := split(env, "=")[0]
	some pattern
	pattern := _secret_patterns[_]
	contains(upper(key), pattern)
	# Only flag if there is an actual value (not just a declaration)
	parts := split(env, "=")
	count(parts) > 1
	parts[1] != ""
	msg := sprintf("env var '%s' may leak a secret (contains '%s' in name)", [key, pattern])
}

# Warn on missing OCI standard labels
warn[msg] {
	not _has_label("org.opencontainers.image.source")
	msg := "missing recommended label: org.opencontainers.image.source"
}

warn[msg] {
	not _has_label("org.opencontainers.image.description")
	msg := "missing recommended label: org.opencontainers.image.description"
}

# Deny images with no entrypoint
deny[msg] {
	not input.config.Entrypoint
	msg := "image has no Entrypoint set"
}

deny[msg] {
	input.config.Entrypoint
	count(input.config.Entrypoint) == 0
	msg := "image Entrypoint is empty"
}

# Helper: check if a label key exists
_has_label(key) {
	input.config.Labels[key]
}
