# Example custom Conftest policy: enforce environment variable naming.
#
# nix2container's image.json puts the OCI config under `input["image-config"]`,
# not `input.config` — the latter is what `docker inspect` returns.
package main

import rego.v1

deny contains msg if {
	some i
	env := input["image-config"].Env[i]
	key := split(env, "=")[0]
	key == upper(key)
	contains(key, " ")
	msg := sprintf("env var '%s' contains spaces", [key])
}
