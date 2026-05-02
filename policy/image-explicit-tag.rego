# Container images must use an explicit non-':latest' tag. Pinning ensures
# Flux reconciliation is deterministic and auditable; ':latest' or missing
# tags break that. Self-built images that the operator deliberately auto-rolls
# can be added to allowed_latest_prefixes.

package main

import rego.v1

allowed_latest_prefixes := {
	"ghcr.io/idarlafish/soulmask-server",
}

is_problematic(image) if {
	not contains(image, ":")
}

is_problematic(image) if {
	endswith(image, ":latest")
}

is_allowed(image) if {
	some prefix in allowed_latest_prefixes
	startswith(image, prefix)
}

deny contains msg if {
	some i
	some path, container
	walk(input[i].contents, [path, container])
	is_object(container)
	container.image
	is_string(container.image)
	is_problematic(container.image)
	not is_allowed(container.image)
	_ = path
	msg := sprintf(
		"%s: image %q must use an explicit non-latest tag",
		[input[i].path, container.image],
	)
}
