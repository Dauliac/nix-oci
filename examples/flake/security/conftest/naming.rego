# Example custom Conftest policy: enforce environment variable naming.
package main

deny[msg] {
	some i
	env := input.config.Env[i]
	key := split(env, "=")[0]
	key == upper(key)
	contains(key, " ")
	msg := sprintf("env var '%s' contains spaces", [key])
}
