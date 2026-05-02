# R2 endpoint URL must come from ${S3_ENDPOINT_URL} (Tofu-derived, surfaced via
# the cluster-vars ConfigMap), not hardcoded in manifests. Tofu backend configs
# are exempt because Terraform's backend block doesn't support variable
# interpolation; everything else should use the substitution.

package main

import rego.v1

deny contains msg if {
	some i
	some path, value
	walk(input[i].contents, [path, value])
	is_string(value)
	contains(value, "cloudflarestorage.com")
	msg := sprintf(
		"%s: hardcoded R2 endpoint at path %v — use ${S3_ENDPOINT_URL} from cluster-vars",
		[input[i].path, path],
	)
}
