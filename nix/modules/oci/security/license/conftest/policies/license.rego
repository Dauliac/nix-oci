# Built-in nix-oci Conftest policies for SBOM license compliance.
#
# These rules validate CycloneDX SBOM JSON produced by Syft.
# Input schema: CycloneDX 1.x (input.components[].licenses[].license.id).
package license

import rego.v1

# -------------------------------------------------------------------
# Forbidden licenses — hard deny.  These are strongly copyleft or
# server-side licenses that are incompatible with most proprietary
# and permissive distribution models.
# -------------------------------------------------------------------
_forbidden := {
	"AGPL-3.0-only",
	"AGPL-3.0-or-later",
	"AGPL-1.0-only",
	"AGPL-1.0-or-later",
	"SSPL-1.0",
	"EUPL-1.1",
	"EUPL-1.2",
}

deny contains msg if {
	some component in input.components
	some license_entry in component.licenses
	id := license_entry.license.id
	id in _forbidden
	msg := sprintf("FORBIDDEN license '%s' in component '%s' (version %s)", [
		id,
		component.name,
		object.get(component, "version", "unknown"),
	])
}

# Also catch licenses expressed as name rather than SPDX id
deny contains msg if {
	some component in input.components
	some license_entry in component.licenses
	not license_entry.license.id
	name := license_entry.license.name
	some forbidden in _forbidden
	contains(upper(name), upper(forbidden))
	msg := sprintf("FORBIDDEN license '%s' (by name) in component '%s' (version %s)", [
		name,
		component.name,
		object.get(component, "version", "unknown"),
	])
}

# -------------------------------------------------------------------
# Restricted licenses — warn.  Copyleft licenses that may impose
# distribution obligations.  Override with org-specific policies
# via extraPolicyDirs if your project accepts these.
# -------------------------------------------------------------------
_restricted := {
	"GPL-2.0-only",
	"GPL-2.0-or-later",
	"GPL-3.0-only",
	"GPL-3.0-or-later",
	"LGPL-2.0-only",
	"LGPL-2.0-or-later",
	"LGPL-2.1-only",
	"LGPL-2.1-or-later",
	"LGPL-3.0-only",
	"LGPL-3.0-or-later",
	"MPL-2.0",
	"CDDL-1.0",
	"CDDL-1.1",
	"CPL-1.0",
	"EPL-1.0",
	"EPL-2.0",
}

warn contains msg if {
	some component in input.components
	some license_entry in component.licenses
	id := license_entry.license.id
	id in _restricted
	msg := sprintf("RESTRICTED (copyleft) license '%s' in component '%s' (version %s)", [
		id,
		component.name,
		object.get(component, "version", "unknown"),
	])
}

# -------------------------------------------------------------------
# Missing license — warn on components with no license information.
# -------------------------------------------------------------------
warn contains msg if {
	some component in input.components
	not component.licenses
	component.type == "library"
	msg := sprintf("component '%s' (version %s) has NO license information", [
		component.name,
		object.get(component, "version", "unknown"),
	])
}

warn contains msg if {
	some component in input.components
	component.licenses
	count(component.licenses) == 0
	component.type == "library"
	msg := sprintf("component '%s' (version %s) has EMPTY license list", [
		component.name,
		object.get(component, "version", "unknown"),
	])
}
