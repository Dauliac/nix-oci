# Example custom Conftest policy: require a "team" label.
#
# nix2container's image.json puts the OCI config under `input["image-config"]`,
# not `input.config` — the latter is what `docker inspect` returns.
package main

import rego.v1

deny contains msg if {
	not input["image-config"].Labels["team"]
	msg := "missing required 'team' label"
}
