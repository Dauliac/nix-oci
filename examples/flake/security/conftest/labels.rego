# Example custom Conftest policy: require a "team" label.
package main

deny[msg] {
	not input.config.Labels["team"]
	msg := "missing required 'team' label"
}
